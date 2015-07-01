#!/bin/sh
#

test_description='Native support for rev-parse of objects in submodules

This test verifies that rev-parse understands how to parse names of objects
belonging to submodules of the current project.
'

. ./test-lib.sh


test_expect_success 'setup a submodule tree' '
	echo file > file &&
	git add file &&
	test_tick &&
	git commit -m upstream &&
	git clone . super &&
	git clone super submodule &&
	(
		cd super &&
		git submodule add ../submodule submodule1 &&
		git submodule add ../submodule submodule2 &&
		git submodule add ../submodule sub3 &&
		git config -f .gitmodules --rename-section \
			submodule.submodule1 submodule.foo1 &&
		git config -f .gitmodules --rename-section \
			submodule.submodule2 submodule.foo2 &&
		git config -f .gitmodules --rename-section \
			submodule.sub3 submodule.foo3 &&
		git add .gitmodules &&
		test_tick &&
		git commit -m "submodules" &&
		git submodule init submodule1 &&
		git submodule init submodule2 &&
		git submodule init sub3
	) &&
	(
		cd submodule &&
		echo different > file &&
		git add file &&
		test_tick &&
		git commit -m "different"
	) &&
	(
		cd super &&
		(
			cd sub3 &&
			git pull
		) &&
		git add sub3 &&
		test_tick &&
		git commit -m "update sub3"
	)
'

submodule1sha1=$(cd super/submodule1 && git rev-parse HEAD)
submodule2sha1=$(cd super/submodule2 && git rev-parse HEAD)
sub3sha1=$(cd super/sub3 && git rev-parse HEAD)

cat > expect <<EOF
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	file
160000 commit $submodule1sha1	submodule1
160000 commit $submodule2sha1	submodule2
160000 commit $sub3sha1	sub3
EOF

test_expect_success 'setup nested submodules' '
	git clone submodule nested1 &&
	git clone submodule nested2 &&
	(
		cd nested1 &&
		mkdir subdir &&
		git submodule add ../nested2 subdir/nested3 &&
		git submodule add ../nested2 nested2 &&
		test_tick &&
		git commit -m "nested2 and subdir/nested3" &&
		git submodule init nested2 &&
		git submodule init subdir/nested3
	) &&
	(
		cd super &&
		mkdir subdir &&
		git submodule add ../nested1 subdir/nested1 &&
		cd subdir &&
		test_tick &&
		git commit -m "nested1" &&
		git submodule update --init --recursive
	)
'

test_expect_success 'setup partially updated nested submodules' '
	git clone super clone2 &&
	(
		cd clone2 &&
		git submodule update --init &&
		test_must_fail git rev-parse --resolve-git-dir subdir/nested1/nested2/.git &&
		git submodule foreach "git submodule update --init" &&
		git rev-parse --resolve-git-dir subdir/nested1/nested2/.git &&
		test_must_fail git rev-parse --resolve-git-dir subdir/nested1/nested2/nested3/.git
	)
'
test_expect_success 'rev-parse does not recurse by default' '
	(
		cd super &&
		test_must_fail git rev-parse HEAD:submodule1/file
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:submodule/file' '
	(
		cd super &&
		git -C submodule1 rev-parse $(git rev-parse master:submodule1):file >expected &&
		git rev-parse --recurse-submodules master:submodule1/file >actual &&
		test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules $sha1:submodule/file' '
	(
		cd super &&
		git -C submodule1 rev-parse $(git rev-parse HEAD:submodule1):file >expected &&
		git rev-parse --recurse-submodules $(git rev-parse HEAD):submodule1/file >actual &&
		test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules HEAD:submodule/non-existent-file fails' '
	(
		cd super &&
		test_must_fail git rev-parse --recurse-submodules HEAD:submodule1/notafile
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:subdir/submodule/file' '
	(
		cd super &&
		git -C subdir/nested1 rev-parse $(git rev-parse HEAD:subdir/nested1):file >expected &&
		git rev-parse --recurse-submodules HEAD:subdir/nested1/file >actual &&
		test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:subdir/submodule1/submodule2/file' '
	(
		cd super &&
		git -C subdir/nested1/nested2 rev-parse $(git -C subdir/nested1 rev-parse HEAD:nested2):file >expected &&
		git rev-parse --recurse-submodules HEAD:subdir/nested1/nested2/file >actual &&
		test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:submodule1/dir1/submodule2' '
	(
	cd super &&
	git -C subdir/nested1 rev-parse HEAD:subdir/nested3 >expected &&
	git rev-parse --recurse-submodules HEAD:subdir/nested1/subdir/nested3 >actual &&
	test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:submodule1/dir1/submodule2/' '
	(
	cd super &&
	git -C subdir/nested1 rev-parse HEAD:subdir/nested3 >expected &&
	git rev-parse --recurse-submodules HEAD:subdir/nested1/subdir/nested3/ >actual &&
	test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:submodule1/dir1/submodule2/file' '
	(
		cd super &&
		git -C subdir/nested1/subdir/nested3 rev-parse $(git -C subdir/nested1 rev-parse HEAD:subdir/nested3):file >expected &&
		git rev-parse --recurse-submodules HEAD:subdir/nested1/subdir/nested3/file >actual &&
		test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:dir1/submodule1/submodule2' '
	(
		cd super &&
		git -C subdir/nested1 rev-parse $(git rev-parse HEAD:subdir/nested1):nested2 >expected &&
		git rev-parse --recurse-submodules HEAD:subdir/nested1/nested2 >actual &&
		test_cmp expected actual
	)
'
test_expect_success 'rev-parse --recurse-submodules $branch:dir1/submodule1/submodule2/file' '
	(
		cd super &&
		git -C subdir/nested1/nested2 rev-parse $(git -C subdir/nested1 rev-parse HEAD:nested2):file >expected &&
		git rev-parse --recurse-submodules HEAD:subdir/nested1/nested2/file >actual &&
		test_cmp expected actual
	)
'

test_done
