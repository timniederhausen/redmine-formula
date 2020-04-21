{% from 'redmine/map.jinja' import redmine, instances with context %}

{% for pkg in redmine.packages %}
redmine_pkg_{{ pkg }}:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}

{%- do salt.log.error(instances) -%}

{% for instance in instances -%}
{%  set index = loop.index -%}
redmine_user_{{ index }}:
  user.present:
    - name: {{ instance.user }}

redmine_group_{{ index }}:
  group.present:
    - name: {{ instance.group }}

redmine_directory_{{ index }}:
  file.directory:
    - name: {{ instance.directory }}
    - user: {{ instance.user }}
    - group: {{ instance.group }}
    - makedirs: true

redmine_checkout_{{ index }}:
  svn.latest:
    - name: {{ instance.svn_url }}
    - target: {{ instance.directory }}
    - rev: {{ instance.svn_rev }}
    - force: true
    - user: {{ instance.user }}
    - trust: true

{%  for cfg in ['configuration', 'database'] %}
redmine_config_{{ index }}_{{ cfg }}:
  file.serialize:
    - name: {{ instance.directory }}/config/{{ cfg }}.yml
    - formatter: yaml
    - user: {{ instance.user }}
    - group: {{ instance.group }}
    - makedirs: true
    - dataset: {{ instance.config.get(cfg, {}) | yaml }}
{%  endfor %}

redmine_local_gemfile_{{ index }}:
  file.managed:
    - name: {{ instance.directory }}/Gemfile.local
    - source: salt://redmine/files/Gemfile.local
    - user: {{ instance.user }}
    - group: {{ instance.group }}

{%  for name, plugin in instance.plugins.present.items() %}
redmine_plugin_{{ index }}_{{ name }}_dir:
  git.latest:
    - name: {{ plugin.git_repo }}
    - target: {{ instance.directory }}/plugins/{{ name }}
    - user: {{ instance.user }}
    - rev: master
    - branch: master
    - force_reset: true
    - force_fetch: true
 {%  if plugin.install_command is defined %}
redmine_plugin_install_{{ index }}_{{ name }}:
  cmd.run:
    - name: {{ plugin.install_command }} && touch "{{ instance.directory }}/plugins/{{ name }}/.installed.stamp"
    - creates: {{ instance.directory }}/plugins/{{ name }}/.installed.stamp
    - cwd: {{ instance.directory }}/plugins/{{ name }}
    - runas: {{ instance.user }}
 {%  endif %}
{%  endfor %}

redmine_bundle_install_{{ index }}:
  cmd.run:
    {# needed to bypass the euid/uid check in ruby that leads to $SAFE=1 #}
    - name: su {{ instance.user }} -c "bundle install --path vendor/bundle --without development test rmagick"
    - runas: {{ instance.user }}
    - cwd: {{ instance.directory }}
    - creates: {{ instance.directory }}/Gemfile.lock

redmine_bundle_update_{{ index }}:
  cmd.run:
    - name: su {{ instance.user }} -c "bundle update"
    - runas: {{ instance.user }}
    - cwd: {{ instance.directory }}
    - onchanges:
      - svn: redmine_checkout_{{ index }}
      - file: redmine_local_gemfile_{{ index }}
      - file: redmine_config_{{ index }}_database
{%  for name in instance.plugins.present.keys() %}
      - git: redmine_plugin_{{ index }}_{{ name }}_dir
{%  endfor %}

redmine_web_sh_{{ index }}:
  file.managed:
    - name: {{ instance.directory }}/bin/web
    - source: salt://redmine/files/web.sh
    - user: {{ instance.user }}
    - group: {{ instance.group }}
    - mode: 755

redmine_secret_token_{{ index }}:
  cmd.run:
    - name: su {{ instance.user }} -c "bundle exec rake generate_secret_token"
    - runas: {{ instance.user }}
    - cwd: {{ instance.directory }}
    - creates: {{ instance.directory }}/config/initializers/secret_token.rb
    - env:
      - RAILS_ENV: production

redmine_migrate_db_{{ index }}:
  cmd.run:
    - name: su {{ instance.user }} -c "bundle exec rake db:migrate"
    - runas: {{ instance.user }}
    - cwd: {{ instance.directory }}
    - env:
      - RAILS_ENV: production
    - onchanges:
      - svn: redmine_checkout_{{ index }}
      - file: redmine_config_{{ index }}_database

redmine_default_data_{{ index }}:
  cmd.run:
    - name: su {{ instance.user }} -c "bundle exec rake redmine:load_default_data"
    - runas: {{ instance.user }}
    - cwd: {{ instance.directory }}
    - env:
      - RAILS_ENV: production
      - REDMINE_LANG: en
    - onchanges:
      - cmd: redmine_migrate_db_{{ index }}
      - file: redmine_config_{{ index }}_database

redmine_plugin_migrate_{{ index }}:
  cmd.run:
    - name: su {{ instance.user }} -c "bundle exec rake redmine:plugins:migrate RAILS_ENV=production"
    - runas: {{ instance.user }}
    - cwd: {{ instance.directory }}
    - env:
      - RAILS_ENV: production
    - onchanges:
      - cmd: redmine_migrate_db_{{ index }}
{%  for name in instance.plugins.present.keys() %}
      - git: redmine_plugin_{{ index }}_{{ name }}_dir
{%  endfor %}

{%  for name in instance.plugins.absent %}
redmine_plugin_{{ index }}_{{ name }}_migrate:
  cmd.run:
    - name: su {{ instance.user }} -c "bundle exec rake redmine:plugins:migrate NAME={{ name }} VERSION=0"
    - runas: {{ instance.user }}
    - cwd: {{ instance.directory }}
    - env:
      - RAILS_ENV: production
    - onlyif: 'test -e {{ instance.directory }}/plugins/{{ name }}'
redmine_plugin_{{ index }}_{{ name }}_dir:
  file.absent:
    - name: {{ instance.directory }}/plugins/{{ name }}
{%  endfor %}
{% endfor %}
