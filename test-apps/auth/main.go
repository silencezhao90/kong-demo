package main

import (
	"fmt"
	"net/http"
)

func indexHandler(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")
	passwd := r.URL.Query().Get("passwd")
	content := fmt.Sprintf("username:%v, passwd:%v", username, passwd)
	if username == "test" && passwd == "123456" {
		w.WriteHeader(403)
	} else {
		w.WriteHeader(200)
	}
	fmt.Fprintf(w, content)
	fmt.Println(content)
	fmt.Println("RequestURI", r.RequestURI)
}

func main() {
	http.HandleFunc("/", indexHandler)
	http.ListenAndServe(":8088", nil)
}
