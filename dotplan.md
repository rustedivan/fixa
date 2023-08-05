#  Fixa dotplan

## Feature plan
- if registration is invalid, we get endless disconnection spam
- connecting twice breaks the connection
- default value should be set when registering fixables, no value in having multiple defaults

- autoconnect to apps if checked
- auto-select midicontroller if clientState.selectedController exists

- "throttled" mode that debounces changes for 0.5 seconds if client-side reactions are slow
- register tweakables with app icon
- string tweaker
- don't send textfield edits before Enter keystroke
- int tweaker
- dropdown tweaker
- array tweaker
- range tweaker
- image reader
- generate/copy settings report
- undo stack
- connected icon in status bar or local notification or corner overlay
- event tweaker
- bool tweaker
- angle/knob tweaker
- disable in production builds
- can the settings report say the name of its variable?
- instances must be able to dereg themselves on destruction (just check that it does, .weakMemory should handle it)

? iOS 14 permission request

√ MIDI controller
√ groupable controllers
√ FixableConfig should not hold the value on the app side
√ don't key to labels, but to H(label + index) so labels don't have to be unique 
√ save/restore
x warn if FixableFloat is created without a FixaStream
x reformulate grouped controls as a list of controls that should move into the group, that should make things a lot cleaner
√ move groups to tabs
