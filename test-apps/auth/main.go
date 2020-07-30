package main

import (
	"fmt"
	"net/http"
)

func indexHandler(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	content := fmt.Sprintf("token:%v", token)
	if token == "abcabc" {
		w.WriteHeader(200)
	} else {
		w.WriteHeader(403)
	}
	fmt.Fprintf(w, content)
	fmt.Println(content)
	fmt.Println("RequestURI", r.RequestURI)
}

func main() {
	http.HandleFunc("/", indexHandler)
	http.ListenAndServe(":8088", nil)
}
