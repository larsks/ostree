#!/bin/bash
#
# Copyright (C) 2016 Colin Walters <walters@verbum.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

set -euo pipefail

if ! fusermount --version >/dev/null 2>&1; then
    echo "1..0 # SKIP no fusermount"
    exit 0
fi

. $(dirname $0)/libtest.sh
setup_test_repository "bare-user"

echo "1..5"

mkdir mnt

$OSTREE checkout test2 checkout-test2

rofiles-fuse checkout-test2 mnt
cleanup_fuse() {
    fusermount -u ${test_tmpdir}/mnt || true
}
trap cleanup_fuse EXIT
assert_file_has_content mnt/firstfile first
echo "ok mount"

if cp /dev/null mnt/firstfile 2>err.txt; then
    assert_not_reached "inplace mutation"
fi
assert_file_has_content err.txt "Read-only file system"
assert_file_has_content mnt/firstfile first
assert_file_has_content checkout-test2/firstfile first

echo "ok failed inplace mutation"

echo anewfile-for-fuse > mnt/anewfile-for-fuse
assert_file_has_content mnt/anewfile-for-fuse anewfile-for-fuse
assert_file_has_content checkout-test2/anewfile-for-fuse anewfile-for-fuse

mkdir mnt/newfusedir
for i in $(seq 5); do
    echo ${i}-morenewfuse-${i} > mnt/newfusedir/test-morenewfuse.${i}
done
assert_file_has_content checkout-test2/newfusedir/test-morenewfuse.3 3-morenewfuse-3

echo "ok new content"

rm mnt/baz/cow
assert_not_has_file checkout-test2/baz/cow
rm mnt/baz/another -rf
assert_not_has_dir checkout-test2/baz/another

echo "ok deletion"

${CMD_PREFIX} ostree --repo=repo commit -b test2 -s fromfuse --link-checkout-speedup --tree=dir=checkout-test2

echo "ok commit"
