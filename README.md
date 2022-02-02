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
 | _ Resource
     | _ [Model_DIR]
         | _ _metadata.yaml
	 | _ ...
```

### Metadata format
```
name: <String>
language: <Locale>
conversation:
  type: "local" / "remote"
  src: <relative path> / <URL>
destinations:
  type: "local" / "remote"
  src: <relative path> / <URL>
location:
  ibeacon-uuid: <UUID String> # for beacon scanning
  latlng: <Lat,Lng> # to determine location automatically
  radius: <number> # in meters
```
