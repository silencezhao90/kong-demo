FROM golang:1.14.3-alpine as build

COPY . /app
WORKDIR /app
RUN go build -o server main.go
RUN chmod +x ./server

FROM alpine:latest

COPY --from=build /app /app
EXPOSE 8080
CMD ["/app/server"]