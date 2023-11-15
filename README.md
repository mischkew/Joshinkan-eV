# Joshinkan e.V.


## Development

**Requirements**
- nginx
- make
- sed
- realpath
- swift 5.8
- mkcert (`brew install mkcert`) 
- gcloud (Google Cloud Platform client, for dpeloyment)

**Installation**

Setup the local SSL certificate chain as the development server runs in https as well. We use `mkcert` to generate a CA for your own developer certificates. If you already use `mkcert` for other projects you can skip step 1.

- Step 1 - Install CA: `mkcert -install`
- Step 2 - Generate developer SSL certificates: `mkcert localhost 127.0.0.1 ::1`
  Two files should be generated: `localhost+2.pem` and `localhost+2-key.pem`. If the filenames differ, rename the files.
- Step 3 - Copy `template.env` to `.env` and setup the variables.

**Usage**

``` bash
# Start the nginx server and backend for local development. Will automatically compile the backend.
make start

# Then watch for changes as you are devving
make watch
```


The website files are in src. Html files may contain `{{ CMD }}` templates. `CMD` can be an arbitrary shell command. The output of the shell command (`stdout`) is placed instead of the template. The `./src/scripts` folder is available in the `$PATH`. 

Templates included via the `include.sh` script are resolved recursively. 

Variables can be defined in the `src/variables.ini` file. They can be read in an html file or template via `variable.sh`.

nginx is only required during development. Deployment is handled via Google Cloud Platform.

## Deployment 

```bash
make deploy
``` 

**First Time Configuration**

The website is hosted with Google Cloud Platform on Google App Engine. For
first-time deployment follow these steps:
- Login via `gcloud init`
- Select a Google Project
- `make deploy`
- Manage domain mapping via 1blu.de, e.g. *-appspot.com -> joshinkan.de


