{% from 'redmine/map.jinja' import redmine with context %}

redmine_unicorn_script:
  file.managed:
    - name: {{ redmine.root_directory }}/config/unicorn.rb
    - source: salt://redmine/files/unicorn.rb
    - template: jinja
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}
    - mode: 600
