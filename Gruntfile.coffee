module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

  grunt.loadTasks('tasks')
  grunt.registerTask 'default', [
    'download-companies'
    'download-addresses'
    'geocode-addresses'
  ]
