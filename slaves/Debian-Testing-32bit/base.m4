FROM 32bit/debian:testing

include(debian.m4)
include(boost-1.59.0.m4)
include(buildbot.m4)

RUN mv /bin/uname /bin/uname.orig && \
  echo '#!/bin/sh\n/usr/bin/linux32 /bin/uname.orig "$@"' > /bin/uname && \
  chmod +x /bin/uname

include(gcc-4.9.m4)
