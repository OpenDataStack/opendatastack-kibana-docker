## Description

This is the OpenDataStack Kibana image.

* Install required python virtualenv dependencies

```sh
$ make venv
```

* Make the kibana-opendatastack image locally.

```sh
$ make build
```

* Run the automated tests.

```sh
$ make test
```

* Get the sample docker-compose.yml file built.

```sh
$ make docker-compose
$ docker-compose up
```
