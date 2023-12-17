## I18NText

```
<attribute>             -- default attribute
<attribute>-<lang>      -- attribute for display in lang (ex. ja, en)
<attribute>-<lang>-pron -- attribute for reading in lang
```

## Source

- type: local/remote
- src: path to file / href

## Location

The following parameter may be used for loading network (not used)
```    
- lat: <Double>    = latitude
- lng: <Double>    = longitude
- dist: <Double>   = distance
```

The following may be used to locate by beacons (not used)
```
- ibeacon-uuids: [<UUID>]
```

## Metadata

```
- name: <I18NText>                       = Name of the resource
- language: <lang>                       = specify if 
- conversation: <Source:JSScript>        = Conversation script => move to conversation server
- destinationAll: <Source:[Destination]> = All destinations for conversation script
- destinations: <Source:[Destination]>   = Root destination view
- tours: <Source:[Tour]>                 = List of tours
- custom_menus: [<CustomMenu>]           = Custom menus
- subtours: <Source:[Destination]>       = **Deprecated**
- location: <Location>                   = Location parameter
```


## Resource
```
- _metadata.yaml: <Metadata>
```

## Tour
```
- title: <I18NText>                      = Title of a tour
- id: <String>                           = Identification of the tour
- introduction: I18NText?                = Text used to announce about sub tour
- destinations: [<Destination>]          = List of destinations
```

## Destination
```
- ref: <Reference:Destination>?          = <File>/<Value[@Angle]>  - a destination may have ref and other attributes, attribute overrides the referenced destination
- title: I18NText?                       = Title of a destination or a group of destination
- file: <Source:[Destination]>?          = Source to a group of destination
- value: <Node ID>[@<Angle>]?            = The destination node [and heading angle after arrival]
- startMessage: <Source:Text>?           = Message text when the robot start navigation
- arrivalMessages: [<Source:Text>]?      = Messages text when the robot arrival (can be repeated the last one)
- content: <Source: HTML>?               = HTML content shown at arrival
- waitingDestination: <Destination>?     = The destination node where the robot may wait
- subtour: <Reference:Tour>              = <File>/<ID>
```

## CustomMenu

```
- title: <I18NText>
- id: <String>
- script: <Source:JSScript>
- function: <JSfunction>
```
