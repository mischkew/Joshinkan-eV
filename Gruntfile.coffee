#global module:false

"use strict"

module.exports = (grunt) ->
  grunt.loadNpmTasks "grunt-contrib-connect"
  grunt.loadNpmTasks "grunt-contrib-copy"
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-exec"

  grunt.initConfig

    #
    # Frontend Dependencies
    # We are currently not using any frontend build system and thus we have to
    # copy our components into the src folder in order to build the jekyll
    # setup.
    #

    copy:
      bootstrap:
        files: [{
          expand: true
          cwd: "node_modules/bootstrap-sass/assets/stylesheets/"
          src: ["**"]
          dest: "src/_sass/vendor"
        }]
      glyphicons:
        files: [{
          expand: true
          cwd: "node_modules/bootstrap-sass/assets/fonts/"
          src: ["**"]
          dest: "src/fonts"
        }]
      animate:
        files: [{
          expand: true
          cwd: "node_modules/animate-scss/src"
          src: ["**"]
          dest: "src/_sass/vendor/animate"
        }]
      jquery:
        files: [{
          expand: true
          cwd: "node_modules/jquery/dist/"
          src: ["jquery.min.js", "jquery.min.map"]
          dest: "src/javascripts/vendor"
        }]
      miniParallax:
        files: [{
          expand: true
          cwd: "node_modules/mini-parallax/"
          src: ["jquery.mini.parallax.js"]
          dest: "src/javascripts/vendor"
        }]
      wow:
        files: [{
          expand: true
          cwd: "node_modules/wowjs/dist"
          src: ["wow.min.js"]
          dest: "src/javascripts/vendor"
        }]

    exec:
      # https://jekyllrb.com/docs/installation/ubuntu/
      gems:
        cmd: "gem install jekyll:3.8.4 bundler:1.17.1 jekyll-redirect-from:0.16.0 jekyll-email-protect"
      jekyll:
        cmd: "jekyll build --trace"
      deploy:
        cmd: "gcloud app deploy --quiet"
      browse:
        cmd: "glcoud app browse"

    watch:
      options:
        livereload: true
      source:
        files: [
          "node_modules"
          "src/**/*"
          "_config.yml"
        ]
        tasks: [
          "exec:jekyll"
        ]

    connect:
      server:
        options:
          port: 4000
          base: 'public'
          livereload: true

  #
  # Custom Tasks
  #

  grunt.registerTask "install", "Install jekyll 3.8.4", [
    "exec:gems"
  ]

  grunt.registerTask "build", "Generate static website to ./public directory", [
    "copy"
    "exec:jekyll"
  ]

  grunt.registerTask "serve", "Run a development server on localhost:4000", [
    "build"
    "connect:server"
    "watch"
  ]

  grunt.registerTask "deploy", "Deploy the webpage on Google App Engine", [
    "build"
    "exec:deploy"
  ]

  grunt.registerTask "browse", "View the hosted webpage in your default browser", [
    "exec:browse"
  ]

  grunt.registerTask "default", [
    "serve"
  ]
