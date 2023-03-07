[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
# cabot-app

- CaBot app is a bluetooth peripheral app of CaBot. 
- The user need to specify a **team name** in the setting view
  - The app will advertise BLE service as **`CaBot-<team name>`** when it is in foreground
- CaBot's ros1 system needs to be launched with `-e <team name>` option
  - CaBot scans the name and tries to connect when found
- There are multiple IN/OUT characteristics (subject to be changed)
	
## BLE spec

- Service UUID: `35CE0000-5E89-4C0D-A3F6-8A6A507C1BF1`
- characteristics

type|ID|IN/OUT|data|description
---|---|---|---|---
summons|0x09|OUT|text|set the destination of the robot (summon mode), specify a node id
destination|0x10|OUT|text|set the destination of the robot (normal mode), specify a node id or `__cancel__` for cancel
speech|0x200|IN|text|speak input text
navi|0x300|IN|text|navigation status, next or arrived
content|0x400|IN|text|open text as URL in browser
sound|0x500|IN|text|play specified sound, speedUp or speedDown
heart_beat|0x9999|OUT|text|send heart beat every second

## How to build

```
$ carthage bootstrap
$ open CaBot.xcworkspace
```

### Model data structure
```
Main Bundle
 | - Resource
     | - Resource_DIR
         | - _metadata.yaml
	 | - ...
	 | - <language-code>.lproj  # for i18n
```

### Metadata format
```
name: String                         # this should be unique among Resource_DIRs
language: LanguageCode?              # optional, if specified, use the language instead of the system setting
conversation: Source<Conversation>?  # optional, conversation source
destinations: Source<Destinations>?  # optional, destinations source
tours: Source<Tours>?                # optional, tours source
location:
  ibeacon-uuid: [String]             # for beacon scanning
  lat: Float                         # to determine location automatically
  lng: Float                         #
  radius: Int                        # in meters
```

### Source format
```
type: String (local / remote)
src: String (relative path / URL)
```

### Conversation format
- JavaScript to handle conversation
- it needs to implement `function getResponse(request)`
```
custom global objects
Bundle.loadYaml       : returns a list of destination from a specified yaml file
Console.log           : print log
Bluetooth.scanBeacons : scan beacons
Device.type           : device type like iPhone13,3
Device.id             : device vendor uuid
HTTPS.postJSON        : post JSON to a host (not implemented yet)
View.showModalWaitingWithMessage : show modal wait and a message
View.hideModalWaiting            : hide the modal wait
View.alert                       : show an alert with title and message
```

### Destinations format
[DestinationRef | Destination | DestinationEx | DestinationSource]

#### DestinationRef
ref: String

#### Destination format
title: String
value: String?
pron: String?

#### DestinationEx format
title: String
value: String?
pron: String?
message: Source?
content: Source?
waitingDestination: Destination?

#### DestinationSource format
title: String
pron: String?
file:  Source?

### Tours format
[Tour]

#### Tour format
id: String
title: String
destinations: Destinations
