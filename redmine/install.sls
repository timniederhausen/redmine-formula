{% from 'redmine/map.jinja' import redmine with context %}

{% for pkg in redmine.packages %}
redmine_pkg_{{ pkg }}:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}

redmine_user:
  user.present:
    - name: {{ redmine.user }}

redmine_group:
  group.present:
    - name: {{ redmine.group }}

redmine_directory:
  file.directory:
    - name: {{ redmine.directory }}
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}
    - makedirs: true

redmine_checkout:
  svn.latest:
    - name: {{ redmine.svn_url }}
    - target: {{ redmine.directory }}
    - rev: {{ redmine.svn_rev }}
    - force: true
    - user: {{ redmine.user }}
    - trust: true

{% for cfg in ['configuration', 'database'] %}
redmine_config_{{ cfg }}:
  file.managed:
    - name: {{ redmine.directory }}/config/{{ cfg }}.yml
    - source: salt://redmine/files/config.yml
    - template: jinja
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}
    - makedirs: true
    - context:
      cfg: {{ cfg }}
{% endfor %}

redmine_local_gemfile:
  file.managed:
    - name: {{ redmine.directory }}/Gemfile.local
    - source: salt://redmine/files/Gemfile.local
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}

redmine_bundle_install:
  cmd.run:
    - name: bundle install --path vendor/bundle --without development test rmagick
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.directory }}
    - creates: {{ redmine.directory }}/Gemfile.lock

redmine_bundle_update:
  cmd.run:
    - name: bundle update
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.directory }}
    - onchanges:
      - svn: redmine_checkout
      - file: redmine_local_gemfile
      - file: redmine_config_database

redmine_web_sh:
  file.managed:
    - name: {{ redmine.directory }}/bin/web
    - source: salt://redmine/files/web.sh
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}
    - mode: 755

redmine_secret_token:
  cmd.run:
    - name: bundle exec rake generate_secret_token
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.directory }}
    - creates: {{ redmine.directory }}/config/initializers/secret_token.rb
    - env:
      - RAILS_ENV: production

redmine_migrate_db:
  cmd.run:
    - name: bundle exec rake db:migrate
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.directory }}
    - env:
      - RAILS_ENV: production
    - onchanges:
      - svn: redmine_checkout
      - file: redmine_config_database

redmine_default_data:
  cmd.run:
    - name: bundle exec rake redmine:load_default_data
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.directory }}
    - env:
      - RAILS_ENV: production
      - REDMINE_LANG: en
    - onchanges:
      - cmd: redmine_migrate_db
      - file: redmine_config_database
