{% from 'redmine/map.jinja' import redmine with context %}

{% if salt['grains.get']('os_family') == 'FreeBSD' %}
redmine_freebsd_rc.d:
  file.managed:
    - name: /usr/local/etc/rc.d/{{ redmine.service }}
    - source: salt://redmine/files/freebsd-rc.sh
    - template: jinja
    - mode: 755
{% endif %}

redmine_service:
  service.running:
    - name: {{ redmine.service }}
    - enable: {{ redmine.service_enabled }}
{% if salt['grains.get']('os_family') == 'FreeBSD' %}
    - require:
      - file: redmine_freebsd_rc.d
{% endif %}
