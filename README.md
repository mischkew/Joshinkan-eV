# Joshinkan e.V.


## Development

**Requirements**
- nginx
- make
- sed
- realpath
- swift 5.8
- mkcert (`brew install mkcert`) 

**Installation**

Setup the local SSL certificate chain as the development server runs in https as well. We use `mkcert` to generate a CA for your own developer certificates. If you already use `mkcert` for other projects you can skip step 1.

- Step 1 - Install CA: `mkcert -install`
- Step 2 - Generate developer SSL certificates: `make dev-certs`
- Step 3 - Copy `template.env` to `.env` and setup the variables.

**Usage**

``` bash
# Start the nginx server and backend for local development. Will automatically compile the backend.
make start

# Then watch for changes as you are devving
make watch
```


The website files are in `./web`. Html files may contain `{{ CMD }}` templates. `CMD` can be an arbitrary shell command. The output of the shell command (`stdout`) is placed instead of the template. The `./web/scripts` folder is available in the `$PATH`. 

Templates included via the `include.sh` script are resolved recursively. 

Variables can be defined in the `web/variables.ini` file. They can be read in an html file or template via `variable.sh`.

## Deployment 

You can deploy to the following environments:
- `testing`: test.joshinkan.de
- `production`: joshinkan.de

An SSH private key is required to access the servers.

Specify the target environment via an environment variable, e.g

```bash
ENVIRONMENT=testing make upload # upload the files to the server
ENVIRONMENT=testing make bootstrap # only required for a fresh server before first deployment
ENVIRONMENT=testing make deploy # build and restart the services
ENVIRONMENt=testing make log # show a summary of frontend and backend logs
``` 

We are using a fixed ip address for the servers. Adjust the DNS records when adding new instances.
