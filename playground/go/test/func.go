package test

type Dog struct {
	name  string
	age   int
	owner string
}

func NewDog(name string, age int) *Dog {
	return &Dog{name: name, age: age}
}

// SetOwner
func (d *Dog) SetOwner(owner string) {
	d.owner = owner
}

// SetName
func (d *Dog) SetName(name string) {
	if d == nil {
		d = NewDog(name, 0)
		d.name = name
	} else {
		d.name = name
	}
}
