use std::io;

trait Show {
    fn show(&self) -> String;
}

impl Show for i32 {
    fn show(&self) -> String {
        format!("four-byte signed {}", self)
    }
}

impl Show for f64 {
    fn show(&self) -> String {
        format!("eight-byte float {}", self)
    }
}
fn another_function(x: i32, y: i32) {
    println!("The value of x is: {}, y {}", x, y);
}
fn fun1(x: i32, y: i32) {
    println!("The value of x is: {}, y {}", x, y);
}

fn add(left: i32, right: i32) -> i32 {
    return left + right;
}

fn add4(left: i32, right: i32, t: i32, f: i32) -> i32 {
    return left + right + t + f;
}

struct Foo<'a> {
    x: &'a i32,
}
struct Boo<'b> {
    x: &'b i32,
}

const CAMEL_CASE: i32 = 42;

fn bug(left: i32, rigth: i32) -> i32 {
    return left;
}

fn test_signature(a: i32, b: i32, c: i32) -> i32 {
    a + b - c
}
fn test(a: i32) {}
fn test2() {
    test(1)
}
fn test3() {
    test(1);
    test2()
}

fn main() {
    test_signature(1, 2, 3);
    let x = || 42;
    bug(x(), 32);
    bug(x(), 32);

    add(add(1, 2), 3);
    add(add(1, 2), 3);
    let answer = 42;
    let maybe_pi = 3.14;
    let v: Vec<&Show> = vec![&answer, &maybe_pi];
    for d in v.iter() {
        println!("show {}", d.show());
    }
    add4(1, 2, 3, add(1, 2));
    add4(add(1, 2), 3, add(3, 4), 4);
    let y = &5; // this is the same as `let _y = 5; let y = &_y;`
    let f = Foo { x: y };
    let z = &5; // this is the same as `let _y = 5; let y = &_y;`
    let f22 = Boo { x: z };
    another_function(11, 2);
}
