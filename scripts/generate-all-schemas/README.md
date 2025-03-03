Use these scripts to generate JSON schemas.

# Example

## Prerequisites

* Clone https://github.com/oslokommune/golden-path-boilerplate

```shell
cd schema-generator
go install
```

Set this environment variable:

```shell
BOILERPLATE_DIR="$HOME/git/golden-path-boilerplate/boilerplate"
```

## One schema

```shell
./generate-releases.sh --repo oslokommune/golden-path-boilerplate --boilerplate-dir "$BOILERPLATE_DIR" --test app-v9.0.0 --output ../../schemas
```

## All schemas

```shell
./generate-releases.sh --repo oslokommune/golden-path-boilerplate --boilerplate-dir "$BOILERPLATE_DIR"  --output ../../schemas
```
