/*******************************************************************************
 * Copyright (c) 2021  IBM Corporation, Carnegie Mellon University and others
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
// custom global objects
// Bundle.loadYaml       : returns a list of destination from a specified yaml file
// Console.log           : print log
// Bluetooth.scanBeacons : scan beacons
// Device.type           : device type like iPhone13,3
// Device.id             : device vendor uuid
// HTTPS.postJSON        : post JSON to a host (not implemented yet)
// View.showModalWaitingWithMessage : show modal wait and a message
// View.hideModalWaiting            : hide the modal wait
// View.alert                       : show an alert with title and message

/*
 conversation script
 */
function getResponse(request) {
    let text = request.input.text

    var speak = "How can I help you"
    var navi = false
    var dest_info = null
    var output_pron = null
    
    return {
        "output": {
            "log_messages":[],
            "text": [speak]
        },
        "intents":[],
        "entities":[],
        "context":{
            "output_pron": output_pron,
            "navi": navi,
            "dest_info": dest_info,
            "system":{
                "dialog_request_counter":0
            }
        }
    }
}

/*
 custom menu script
 */
function callCustomFunc() {
    View.alert("Hello World")
}
