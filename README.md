# releases

Idealized release API

### Usage

    curl -X POST https://releases-test.herokuapp.com/apps/myapp/release \
         -d "build_url=http%3A%2F%2Fexample.org%2Fslug.img" \
         -d "description=deployed" \
         -d "processes[web]=bundle%20exec%20thin%20start"

### Options

* `build_url` - A URL to a slug in `.img` or `.tgz` format
* `description` - A description of the release
* `processes` - Manually override the process table

### Notes

Process types will be determined by looking inside the slug for a `Procfile`
