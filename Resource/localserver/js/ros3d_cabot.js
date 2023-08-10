/*******************************************************************************
 * Copyright (c) 2023  Carnegie Mellon University and Miraikan
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

/**
 * A PoseStamped client
 *
 * @constructor
 * @param options - object with following keys:
 *
 *  * ros - the ROSLIB.Ros connection handle
 *  * topic - the marker topic to listen to
 *  * tfClient - the TF client handle to use
 *  * rootObject (optional) - the root object to add this marker to
 *  * color (optional) - color for line (default: 0xcc00ff)
 *  * length (optional) - the length of the arrow (default: 1.0)
 *  * headLength (optional) - the head length of the arrow (default: 0.2)
 *  * shaftDiameter (optional) - the shaft diameter of the arrow (default: 0.05)
 *  * headDiameter (optional) - the head diameter of the arrow (default: 0.1)
 */
ROS3D.PoseLog = function(options) {
  THREE.Object3D.call(this);
  this.options = options || {};
  this.ros = options.ros;
  this.topicName = options.topic || '/pose';
  this.tfClient = options.tfClient;
  this.color = options.color || 0xcc00ff;
  this.rootObject = options.rootObject || new THREE.Object3D();

  this.poses = [];

  this.rosTopic = undefined;
  this.subscribe();
};
ROS3D.PoseLog.prototype.__proto__ = THREE.Object3D.prototype;


ROS3D.PoseLog.prototype.unsubscribe = function(){
  if(this.rosTopic){
    this.rosTopic.unsubscribe(this.processMessage);
  }
};

ROS3D.PoseLog.prototype.subscribe = function(){
  this.unsubscribe();

  // subscribe to the topic
  this.rosTopic = new ROSLIB.Topic({
      ros : this.ros,
      name : this.topicName,
      queue_length : 1,
      messageType : 'cabot_msgs/msg/PoseLog'
  });
  this.rosTopic.subscribe(this.processMessage.bind(this));
};

ROS3D.PoseLog.prototype.processMessage = function(message){
  if (this.poses.length > 1) {
    this.poses[0].unsubscribeTf();
    this.rootObject.remove(this.poses[0]);
    this.poses.shift();
  }

  this.options.origin = new THREE.Vector3( message.pose.position.x, message.pose.position.y,
                                           message.pose.position.z);

  var rot = new THREE.Quaternion(message.pose.orientation.x, message.pose.orientation.y,
                                 message.pose.orientation.z, message.pose.orientation.w);
  this.options.direction = new THREE.Vector3(1,0,0);
  this.options.direction.applyQuaternion(rot);
  this.options.material = new THREE.MeshBasicMaterial({color: this.color});
  var arrow = new ROS3D.Arrow(this.options);

  var node = new ROS3D.SceneNode({
      frameID : message.header.frame_id,
      tfClient : this.tfClient,
      object : arrow
  });

  this.poses.push(node);
  this.rootObject.add(node);

  var correction = new THREE.Vector3();
  const sceneNode = this.rootObject.children.find(sceneNode => sceneNode.frameID == 'map_global');
  if (sceneNode) {
    correction =  sceneNode.position;
  }

  this.rootObject.position.x =  -(message.pose.position.x + correction.x);
  this.rootObject.position.y =  -(message.pose.position.y + correction.y);

};


/**
 * @fileOverview
 * @author yoshizawa
 */

/**
 * A People client
 *
 * @constructor
 * @param options - object with following keys:
 *
 *  * ros - the ROSLIB.Ros connection handle
 *  * topic - the marker topic to listen to
 *  * tfClient - the TF client handle to use
 *  * rootObject (optional) - the root object to add this marker to
 *  * color (optional) - color for line (default: 0xcc00ff)
 *  * radius (optional) - radius of the point (default: 0.2)
 */
ROS3D.People = function(options) {
  THREE.Object3D.call(this);
  this.options = options || {};
  this.ros = options.ros;
  this.topicName = options.topic || '/people';
  this.tfClient = options.tfClient;
  this.color = options.color || 0x0000ff;
  this.rootObject = options.rootObject || new THREE.Object3D();
  this.radius = options.radius || 0.2;

  this.peoples = [];

  this.rosTopic = undefined;
  this.subscribe();
};


ROS3D.People.prototype.__proto__ = THREE.Object3D.prototype;

ROS3D.People.prototype.unsubscribe = function(){
  if(this.rosTopic){
    this.rosTopic.unsubscribe(this.processMessage);
  }
};

ROS3D.People.prototype.subscribe = function(){
  this.unsubscribe();

  // subscribe to the topic
  this.rosTopic = new ROSLIB.Topic({
      ros : this.ros,
      name : this.topicName,
      queue_length : 1,
      messageType : 'people_msgs/msg/People'
  });
  this.rosTopic.subscribe(this.processMessage.bind(this));
};

ROS3D.People.prototype.processMessage = function(message){

  for (let i = 0; i < this.peoples.length; i++) {
      this.rootObject.remove(this.peoples[i]);
  }

  if (message.people.length > 0) {
      this.peoples = [];

      message.people.forEach(person => {
          var sphereGeometry = new THREE.SphereGeometry( this.radius );
          var sphereMaterial = new THREE.MeshBasicMaterial( {color: this.color} );
          var sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
          sphere.position.set(person.position.x, person.position.y, person.position.z);

          var node = new ROS3D.SceneNode({
              frameID : message.header.frame_id,
              tfClient : this.tfClient,
              object : sphere
          });

          this.peoples.push(node);
          this.rootObject.add(node);
      });

  }
};
