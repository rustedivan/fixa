// Tweak server has a persistent key-value store
// Tweak value connects to the KVS on creation to get its value
// Tweak value disconnects from the KVS on
// Tweak server updates Tweak value from the KVS on changes
// Tweak values are read-only from the client's side
// Tweak value calls its didSet {} equiv
// Multiple Tweak values with the same key is allowed

class Inner {
	let lol = 5
	deinit {
		print("Died")
	}
}

struct Outer {
	let inner = Inner()
}

var p1 = Outer()
var p2 = Outer()

p1 = p2
