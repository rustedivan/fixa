#  Fixa dotplan

## POC
√ send tweakables dictionary from server app
√ send tweak messages from control client
√ rename to "controller" and "app"
√ disconnect on window close
- start listener on app resume ----- does the app stop listening on connect?
√ figure out RAII-style registration with app dictionary
√ publisher instead of setCallback
√ FixableName cannot be an enum (can't cross package boundary)
- inObservableObject
√ clean up into framework
- Float to Double?
- rename fixa-app to fixa-example
- merge down to public main

## Features
- register tweakables with app icon
- FixaStream should validate that all labels are unique
- string tweaker
- int tweaker
- dropdown tweaker
- array tweaker
- image reader
- MIDI controller
- generate/copy settings report
- undo stack
- save/restore
- filter tweaker controls
- connected icon in status bar or local notification or corner overlay
- send up app icon
- event tweaker
- bool tweaker
- angle/knob tweaker
- can the settings report say the name of its variable?
