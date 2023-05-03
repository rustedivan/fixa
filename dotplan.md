#  Fixa dotplan

## Feature plan
- iOS 14 permission request
- groupable controllers
- if registration is invalid, we get endless disconnection spam
√ FixableConfig should not hold the value on the app side
- "throttled" mode that debounces changes for 0.5 seconds if client-side reactions are slow
√ don't key to labels, but to H(label + index) so labels don't have to be unique 
- register tweakables with app icon
- string tweaker
- int tweaker
- dropdown tweaker
- array tweaker
- image reader
- MIDI controller
- generate/copy settings report
- undo stack
√ save/restore
- connected icon in status bar or local notification or corner overlay
- event tweaker
- bool tweaker
- angle/knob tweaker
- can the settings report say the name of its variable?
- instances must be able to dereg themselves on destruction (just check that it does, .weakMemory should handle it)


## Grouping
In sendFixableRegistration, fixablesDictionary.allFixables should contain the dividers and groups too, otherwise they won't be added to the FixaMessageRegister. fixablesDictionary.allValues can omit them though.
That means that the FixaRepository should hold lists of dividers and groups too, but can filter them out when constructing allValues.
Then, when the controller gets the initial setup/registration, it can construct the groups and dividers, but doesn't track any value changes on them.
