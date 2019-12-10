#!/bin/bash -e

PRODUCT=scylla

. /etc/os-release
print_usage() {
    echo "build_rpm.sh -target centos7"
    echo "  --target target distribution"
    exit 1
}
TARGET=
while [ $# -gt 0 ]; do
    case "$1" in
        "--target")
            TARGET=$2
            shift 2
            ;;
        *)
            print_usage
            ;;
    esac
done

is_redhat_variant() {
    [ -f /etc/redhat-release ]
}
pkg_install() {
    if is_redhat_variant; then
        sudo yum install -y $1
    else
        echo "Requires to install following command: $1"
        exit 1
    fi
}

if [ ! -e dist/redhat/build_rpm.sh ]; then
    echo "run build_rpm.sh in top of scylla-ami dir"
    exit 1
fi

if [ "$(arch)" != "x86_64" ]; then
    echo "Unsupported architecture: $(arch)"
    exit 1
fi

if [ ! -f /usr/bin/rpmbuild ]; then
    pkg_install rpm-build
fi
if [ ! -f /usr/bin/git ]; then
    pkg_install git
fi
if [ ! -f /usr/bin/pystache ]; then
    if is_redhat_variant; then
        sudo yum install -y python2-pystache || sudo yum install -y pystache
    elif is_debian_variant; then
        sudo apt-get install -y python-pystache
    fi
fi

VERSION=$(./SCYLLA-VERSION-GEN)
SCYLLA_VERSION=$(cat build/SCYLLA-VERSION-FILE)
SCYLLA_RELEASE=$(cat build/SCYLLA-RELEASE-FILE)

RPMBUILD=$(readlink -f build/)
mkdir -p $RPMBUILD/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

git archive --format=tar --prefix=$PRODUCT-ami-$SCYLLA_VERSION/ HEAD -o $RPMBUILD/SOURCES/$PRODUCT-ami-$VERSION.tar
pystache dist/redhat/scylla-ami.spec.mustache "{ \"version\": \"$SCYLLA_VERSION\", \"release\": \"$SCYLLA_RELEASE\", \"product\": \"$PRODUCT\", \"$PRODUCT\": true }" > $RPMBUILD/SPECS/scylla-ami.spec
if [ "$TARGET" = "centos7" ]; then
    rpmbuild -ba --define '_binary_payload w2.xzdio' --define "_topdir $RPMBUILD" --define "dist .el7" $RPM_JOBS_OPTS $RPMBUILD/SPECS/scylla-ami.spec
else
    rpmbuild -ba --define '_binary_payload w2.xzdio' --define "_topdir $RPMBUILD" $RPM_JOBS_OPTS $RPMBUILD/SPECS/scylla-ami.spec
fi
