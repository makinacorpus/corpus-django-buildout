{% set cfg = opts.ms_project %}
{% set data = cfg.data %}
{% set scfg = salt['mc_utils.json_dump'](cfg) %}

{{cfg.name}}-config:
  file.managed:
    - name: {{cfg.project_root}}/{{data.PROJECT}}/settings_local.py
    - source: salt://makina-projects/{{cfg.name}}/files/config.py
    - template: jinja
    - user: {{cfg.user}}
    - data: |
            {{scfg}}
    - group: {{cfg.group}}
    - makedirs: true

static-{{cfg.name}}:
  cmd.run:
    - name: {{cfg.project_root}}/bin/django-admin.py collectstatic --noinput --settings="{{data.DJANGO_SETTINGS_MODULE}}"
    - cwd: {{cfg.project_root}}
    - user: {{cfg.user}}
    - watch:
      - file: {{cfg.name}}-config

syncdb-{{cfg.name}}:
  cmd.run:
    - name: {{cfg.project_root}}/bin/django-admin.py syncdb
    - cwd: {{cfg.project_root}}
    - user: {{cfg.user}}
    - watch:
      - file: {{cfg.name}}-config

{% for admin, udata in data.admins.items() %}
user-{{cfg.name}}-{{admin}}:
  cmd.run:
    - name: {{cfg.project_root}}/bin/django-admin.py createsuperuser --username="{{admin}}" --email="{{udata.mail}}"
    - unless: {{cfg.project_root}}/bin/mypy -c "from django.contrib.auth.models import User;User.objects.filter(username='{{admin}}')[0]"
    - cwd: {{cfg.project_root}}
    - user: {{cfg.user}}
    - watch:
      - file: {{cfg.name}}-config
      - cmd: syncdb-{{cfg.name}}

superuser-{{cfg.name}}-{{admin}}:
  file.managed:
    - contents: |
                from django.contrib.auth.models import User
                user=User.objects.filter(username='{{admin}}').first()
                user.set_password('{{udata.password}}')
                user.save()
    - mode: 600
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - source: ""
    - name: "{{cfg.project_root}}/salt_{{admin}}_password.py"
    - watch:
      - file: {{cfg.name}}-config
      - cmd: syncdb-{{cfg.name}}
  cmd.run:
    - name: {{cfg.project_root}}/bin/mypy "{{cfg.project_root}}/salt_{{admin}}_password.py"
    - cwd: {{cfg.project_root}}
    - user: {{cfg.user}}
    - watch:
      - cmd: user-{{cfg.name}}-{{admin}}
      - file: superuser-{{cfg.name}}-{{admin}}
{%endfor %}
