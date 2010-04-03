#
# Copyright (c) 2009 Mark Heily <mark@heily.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

REPOSITORY=svn+ssh://mark.heily.com/$$HOME/svn/$(PROGRAM)
DIST=heily.com:$$HOME/public_html/$(PROGRAM)/dist
DISTFILE=$(PROGRAM)-$(VERSION).tar.gz

include config.mk

.PHONY :: install uninstall check dist dist-upload publish-www clean merge distclean fresh-build rpm edit cscope

all: $(PROGRAM).so $(PROGRAM).a

%.o: %.c $(DEPS)
	$(CC) -c -o $@ -fPIC -I./include -I./src/common -Wall -Werror $(CFLAGS) $<

$(PROGRAM).a: $(OBJS)
	$(AR) rcs $(PROGRAM).a $(OBJS)

$(PROGRAM).so: $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) $(LDADD)
	$(LN) -sf $(PROGRAM).so.$(ABI_VERSION) $(PROGRAM).so

install: $(PROGRAM).so
	$(INSTALL) -d -m 755 $(INCLUDEDIR)/kqueue/sys
	$(INSTALL) -m 644 include/sys/event.h $(INCLUDEDIR)/kqueue/sys/event.h
	$(INSTALL) -d -m 755 $(LIBDIR) 
	$(INSTALL) -m 644 $(PROGRAM).so.$(ABI_VERSION) $(LIBDIR)
	$(LN) -sf $(PROGRAM).so.$(ABI_VERSION) $(LIBDIR)/$(PROGRAM).so.$(ABI_MAJOR)
	$(LN) -sf $(PROGRAM).so.$(ABI_VERSION) $(LIBDIR)/$(PROGRAM).so
	$(INSTALL) -m 644 $(PROGRAM).la $(LIBDIR)
	$(INSTALL) -m 644 $(PROGRAM).a $(LIBDIR)
	$(INSTALL) -d -m 755 $(LIBDIR)/pkgconfig
	$(INSTALL) -m 644 libkqueue.pc $(LIBDIR)/pkgconfig
	$(INSTALL) -d -m 755 $(MANDIR)/man2
	$(INSTALL) -m 644 kqueue.2 $(MANDIR)/man2/kqueue.2
	$(INSTALL) -m 644 kqueue.2 $(MANDIR)/man2/kevent.2

uninstall:
	rm -f $(INCLUDEDIR)/kqueue/sys/event.h
	rm -f $(LIBDIR)/libkqueue.so 
	rm -f $(LIBDIR)/pkgconfig/libkqueue.pc 
	rm -f $(MANDIR)/man2/kqueue.2 
	rm -f $(MANDIR)/man2/kevent.2 
	rmdir $(INCLUDEDIR)/kqueue/sys $(INCLUDEDIR)/kqueue

check: $(PROGRAM).a
	cd test && ./configure && make check

$(DISTFILE): $(SOURCES) $(HEADERS)
	mkdir $(PROGRAM)-$(VERSION)
	cp  Makefile ChangeLog configure config.inc      \
        $(MANS) $(EXTRA_DIST)   \
        $(PROGRAM)-$(VERSION)
	cp -R $(SUBDIRS) $(PROGRAM)-$(VERSION)
	rm -rf `find $(PROGRAM)-$(VERSION) -type d -name .svn -o -name .libs`
	cd $(PROGRAM)-$(VERSION) && ./configure && cd test && ./configure && cd .. && make distclean
	tar zcf $(PROGRAM)-$(VERSION).tar.gz $(PROGRAM)-$(VERSION)
	rm -rf $(PROGRAM)-$(VERSION)

dist:
	rm -f $(DISTFILE)
	make $(DISTFILE)

dist-upload: dist
	scp $(PROGRAM)-$(VERSION).tar.gz $(DIST)

publish-www:
	cp -R www/* ~/public_html/libkqueue/

clean:
	rm -f tags *.a $(OBJS) *.so 
	cd test && make clean || true

fresh-build:
	rm -rf /tmp/$(PROGRAM)-testbuild 
	svn co svn://mark.heily.com/libkqueue/trunk /tmp/$(PROGRAM)-testbuild 
	cd /tmp/$(PROGRAM)-testbuild && ./configure && make check
	rm -rf /tmp/$(PROGRAM)-testbuild 

merge:
	svn diff $(REPOSITORY)/branches/stable $(REPOSITORY)/trunk | gvim -
	@printf "Merge changes from the trunk to the stable branch [y/N]? "
	@read x && test "$$x" = "y"
	echo "ok"

tags: $(SOURCES) $(HEADERS)
	ctags $(SOURCES) $(HEADERS)

edit: tags
	$(EDITOR) $(SOURCES) $(HEADERS)
    
cscope: tags
	cscope $(SOURCES) $(HEADERS)

distclean: clean
	rm -f *.tar.gz *.deb *.rpm *.dsc *.changes *.diff.gz \
            config.mk config.h $(PROGRAM).pc $(PROGRAM).la rpm.spec
	rm -rf $(PROGRAM)-$(VERSION) 2>/dev/null || true

rpm: clean $(DISTFILE)
	rm -rf rpm *.rpm *.deb
	mkdir -p rpm/BUILD rpm/RPMS rpm/SOURCES rpm/SPECS rpm/SRPMS
	mkdir -p rpm/RPMS/i386 rpm/RPMS/x86_64
	cp $(DISTFILE) rpm/SOURCES 
	rpmbuild -bb rpm.spec
	mv ./rpm/RPMS/* .
	rm -rf rpm
	rmdir i386 x86_64    # WORKAROUND: These aren't supposed to exist
	fakeroot alien --scripts *.rpm

deb: clean $(DISTFILE)
	tar zxf $(DISTFILE)
	cp $(DISTFILE) $(PROGRAM)_$(VERSION).orig.tar.gz
	mkdir $(PROGRAM)-$(VERSION)/debian
	cp ports/debian/* $(PROGRAM)-$(VERSION)/debian
	cd $(PROGRAM)-$(VERSION) && dpkg-buildpackage
	rm -rf $(PROGRAM)-$(VERSION)

debug-install:
	./configure --prefix=/usr --debug=yes
	make clean && make && sudo make install

diff:
	if [ "`pwd | grep /trunk`" != "" ] ; then \
	   (cd .. ; $(DIFF) branches/stable trunk | less) ; \
    fi
	if [ "`pwd | grep /branches/stable`" != "" ] ; then \
	   (cd ../.. ; $(DIFF) branches/stable trunk | less) ; \
    fi
