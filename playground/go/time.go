package main

import (
	"fmt"
	// "strings"
	"time"

	log "github.com/sirupsen/logrus"
)

// type Name2 struct {
// 	f1 string
// 	f2 int
// }
//
// type name4 struct {
// 	f1 string
// 	f2 int
// }
//
// type name5 struct {
// 	f1 string
// 	f2 int
// }
//
// func test2() {
// 	type some struct {
// 		Success bool `-line:"success"`
// 		Failure bool
// 	}
//
// 	// myfunc("aaa", "bbb")
// }

func myfunc3(v, v2 string) error {
	time.After(time.Hour)
	fmt.Println(v, v2)
	// fmt.Println(kk)
	//

	time.Date(2020, 12, 11, 21, 11, 44, 12, nil)
	time.Date(2020, 1, 11, 11, 11, 2, 1, nil)
	time.Date(1111, 22, 11, 1, 1, 1, 1, nil)
	time.Date(12345, 2333, 444, 555, 66, 1, 22, nil)
	fmt.Println(`kkkkkk`)
	log.Info(`abc`)
	log.Infof(`log %s`, `def`)
	log.Infof(`log %d`, 33)

	return nil
}

// func myfunc4() {
// 	// myfunc("aaa", "bbb") // time.Date(12,11, )
// 	// myfunc("abc", "def")
// 	// myfunc("1", "2")
// }
//
// func mytest2() {
// 	i := 1
// 	log.Infof("%d", i)
// 	myfunc4()
// }
//
// func myfunc5() {
// 	hellostring := "hello"
// 	if strings.Contains(hellostring, "hello") {
// 		fmt.Println("it is there")
// 	}
// }
