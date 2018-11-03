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
          cwd: "bower_components/bootstrap-sass/assets/stylesheets/"
          src: ["**"]
          dest: "src/_sass/vendor"
        }]
      glyphicons:
        files: [{
          expand: true
          cwd: "bower_components/bootstrap-sass/assets/fonts/"
          src: ["**"]
          dest: "src/fonts"
        }]
      animate:
        files: [{
          expand: true
          cwd: "bower_components/animate-scss/src"
          src: ["**"]
          dest: "src/_sass/vendor/animate"
        }]
      jquery:
        files: [{
          expand: true
          cwd: "bower_components/jquery/dist/"
          src: ["jquery.min.js", "jquery.min.map"]
          dest: "src/javascripts/vendor"
        }]
      miniParallax:
        files: [{
          expand: true
          cwd: "bower_components/mini-parallax/"
          src: ["jquery.mini.parallax.js"]
          dest: "src/javascripts/vendor"
        }]
      wow:
        files: [{
          expand: true
          cwd: "bower_components/wowjs/dist"
          src: ["wow.min.js"]
          dest: "src/javascripts/vendor"
        }]

    exec:
      bower:
        cmd: "bower install"
      jekyll:
        cmd: "jekyll build --trace"

    watch:
      options:
        livereload: true
      source:
        files: [
          "bower_components"
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

  grunt.registerTask "build", [
    "exec:bower"
    "copy"
    "exec:jekyll"
  ]

  grunt.registerTask "serve", [
    "build"
    "connect:server"
    "watch"
  ]

  grunt.registerTask "default", [
    "serve"
  ]
