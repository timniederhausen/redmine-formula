{% from 'redmine/map.jinja' import redmine, instances with context %}

{% for instance in instances %}
redmine_unicorn_script_{{ loop.index }}:
  file.managed:
    - name: {{ instance.directory }}/config/unicorn.rb
    - source: salt://redmine/files/unicorn.rb
    - template: jinja
    - user: {{ instance.user }}
    - group: {{ instance.group }}
    - mode: 600
    - context:
        redmine: {{ instance | json }}
{% endfor %}
