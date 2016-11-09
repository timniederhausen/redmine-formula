{% from 'redmine/map.jinja' import redmine with context %}

{% for pkg in redmine.packages %}
pkg_{{ pkg }}:
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
    - name: {{ redmine.root_directory }}
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}
    - makedirs: true

redmine_checkout:
  svn.latest:
    - name: {{ redmine.svn_url }}
    - target: {{ redmine.root_directory }}
    - force: true
    - user: {{ redmine.user }}
    - trust: true

{% for cfg in ['configuration', 'database'] %}
redmine_config_{{ cfg }}:
  file.managed:
    - name: {{ redmine.root_directory }}/config/{{ cfg }}.yml
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
    - name: {{ redmine.root_directory }}/Gemfile.local
    - source: salt://redmine/files/Gemfile.local
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}

redmine_bundle_install:
  cmd.run:
    - name: bundle install --path vendor/bundle --without development test rmagick
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.root_directory }}
    - creates: {{ redmine.root_directory }}/Gemfile.lock

redmine_bundle_update:
  cmd.run:
    - name: bundle update
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.root_directory }}

redmine_web_sh:
  file.managed:
    - name: {{ redmine.root_directory }}/bin/web
    - source: salt://redmine/files/web.sh
    - user: {{ redmine.user }}
    - group: {{ redmine.group }}
    - mode: 755

redmine_secret_token:
  cmd.run:
    - name: bundle exec rake generate_secret_token
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.root_directory }}
    - creates: {{ redmine.root_directory }}/config/initializers/secret_token.rb
    - env:
      - RAILS_ENV: production

redmine_migrate_db:
  cmd.run:
    - name: bundle exec rake db:migrate
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.root_directory }}
    - env:
      - RAILS_ENV: production

redmine_default_data:
  cmd.run:
    - name: bundle exec rake redmine:load_default_data
    - runas: {{ redmine.user }}
    - cwd: {{ redmine.root_directory }}
    - env:
      - RAILS_ENV: production
      - REDMINE_LANG: en
