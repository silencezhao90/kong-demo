package main

import (
	"fmt"
	"net/http"
)

func indexHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusInternalServerError)
	fmt.Fprintf(w, "this is server")
	fmt.Println("RequestURI", r.RequestURI)
}

func lookHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, r.RequestURI)
	fmt.Println("RequestURI", r.RequestURI)
}

func main() {
	http.HandleFunc("/", lookHandler)
	http.HandleFunc("/lookup", indexHandler)
	http.ListenAndServe(":8080", nil)
}
