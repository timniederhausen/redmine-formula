{% from 'redmine/map.jinja' import redmine with context %}

{% if grains.os_family == 'FreeBSD' %}
redmine_service_script:
  file.managed:
    - name: /usr/local/etc/rc.d/{{ redmine.service }}
    - source: salt://redmine/files/freebsd-rc.sh
    - template: jinja
    - mode: 755
{% elif grains.os_family == 'Debian' %}
redmine_service_script:
  file.managed:
    - name: /etc/systemd/system/{{ redmine.service }}.service
    - source: salt://redmine/files/redmine.service
    - template: jinja
    - mode: 755
{% endif %}

redmine_service:
  service.running:
    - name: {{ redmine.service }}
    - enable: {{ redmine.service_enabled }}
{% if grains.os_family in ['FreeBSD', 'Debian'] %}
    - require:
      - file: redmine_service_script
{% endif %}
