# releases

Idealized release API

### Usage

    curl -X POST https://releases-test.herokuapp.com/apps/myapp/release \
         -d "build_url=http%3A%2F%2Fexample.org%2Fslug.img" \         
         -d "description=deployed"
         
### Options

* `build_url` - A URL to a slug in `.img` or `.tgz` format
* `description` - A description of the release

### Notes

Process types will be determined by looking inside the slug for a `Procfile`