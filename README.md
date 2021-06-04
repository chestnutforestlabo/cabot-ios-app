[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
# cabot-app


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