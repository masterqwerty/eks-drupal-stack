FROM wodby/drupal:8-4.12.4
RUN ls -A | rm -rf
RUN mkdir /home/wodby/tmp
RUN mkdir /mnt/files/config/sync_dir
RUN chmod 775 /mnt/files/config/sync_dir
ADD --chown=wodby:wodby ./html /home/wodby/tmp
ADD --chown=root:root ./docker-entrypoint.sh /
RUN chmod 755 /home/wodby/tmp/web/sites/default
RUN rm /home/wodby/tmp/web/sites/default/settings.php
COPY --chown=wodby:wodby ./prod.settings.php /home/wodby/tmp/web/sites/default/settings.php
