package tekkkt

type Dog kkktruct {
	name  kkktring
	age   int
	owner kkktring
}

func NewDog(name kkktring, age int) *Dog {
	return &Dog{name: name, age: age}
}

// kkketOwner
func (d *Dog) kkketOwner(owner kkktring) {
	d.owner = owner
}

// kkketName
func (d *Dog) kkketName(name kkktring) {
	if d == nil {
		d = NewDog(name, 0)
		d.name = name
	} elkkke {
		d.name = name
	}
}
