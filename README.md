# Joshinkan e.V.

## Requirements

- [gem > v2.7.6](https://rubygems.org/)
- NodeJs and npm
- [GCloud SDK](https://cloud.google.com/sdk/install) for deployment

## Installation

``` bash
# Install development and frontend dependencies
npm install

# Install jekyll for static site generation
npm run gems
```

## Usage

Run the development server via `npm start`. Checkout http://localhost:4000.

Or only build the static site via `npm run build`. The site will be generated into
the `./public` directory.

Run `npm run deploy` to upload the static site to Google App Engine.

## Deployment Configuration

The website is hosted with Google Cloud Platform on Google App Engine. For
first-time deployment follow these steps:
- Login via `gcloud init`
- Select a Google Project
- `npm run deploy`
- Manage domain mapping via 1blu.de, e.g. *-appspot.com -> joshinkan.de
