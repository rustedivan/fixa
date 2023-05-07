#  Fixa dotplan

## Feature plan
? iOS 14 permission request
- warn if FixableFloat is created without a FixaStream
- if registration is invalid, we get endless disconnection spam
- MIDI controller

- prevent nestable groups

√ groupable controllers
√ FixableConfig should not hold the value on the app side
- "throttled" mode that debounces changes for 0.5 seconds if client-side reactions are slow
√ don't key to labels, but to H(label + index) so labels don't have to be unique 
- register tweakables with app icon
- string tweaker
- don't send textfield edits before Enter keystroke
- int tweaker
- dropdown tweaker
- array tweaker
- image reader
- generate/copy settings report
- undo stack
√ save/restore
- connected icon in status bar or local notification or corner overlay
- event tweaker
- bool tweaker
- angle/knob tweaker
- disable in production builds
- can the settings report say the name of its variable?
- instances must be able to dereg themselves on destruction (just check that it does, .weakMemory should handle it)
