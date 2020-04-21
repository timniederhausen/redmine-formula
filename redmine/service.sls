{% from 'redmine/map.jinja' import instances with context %}

{% for instance in instances %}
{%  if grains.os_family == 'FreeBSD' %}
redmine_service_script_{{ loop.index }}:
  file.managed:
    - name: /usr/local/etc/rc.d/{{ instance.service }}
    - source: salt://redmine/files/freebsd-rc.sh
    - template: jinja
    - mode: 755
    - context:
      redmine: {{ instance | yaml }}
{%  elif grains.os_family == 'Debian' %}
redmine_service_script:
  file.managed:
    - name: /etc/systemd/system/{{ instance.service }}.service
    - source: salt://redmine/files/redmine.service
    - template: jinja
    - mode: 755
    - context:
      redmine: {{ instance | yaml }}
{%  endif %}

redmine_service_{{ loop.index }}:
  service.running:
    - name: {{ instance.service }}
    - enable: {{ instance.service_enabled }}
{%  if grains.os_family in ['FreeBSD', 'Debian'] %}
    - require:
      - cmd: redmine_default_data_{{ loop.index }}
      - file: redmine_service_script_{{ loop.index }}
{%  endif %}
    - watch:
      - file: redmine_config_{{ loop.index }}_configuration
      - cmd: redmine_migrate_db_{{ loop.index }}
      - cmd: redmine_plugin_migrate_{{ loop.index }}
{%  for name in instance.plugins.absent %}
      - cmd: redmine_{{ loop.index }}_plugin_{{ name }}_migrate
{%  endfor %}
{% endfor %}
