initscriptdir=/etc/init.d
pkglibdir=/lib/cryptsetup
mandir=/usr/share/man
sysconfdir=/etc
initrdscriptsdir=/lib/mkinitrd/scripts

ASCIIDOC=asciidoc

all: crypttab.5 cryptotab.5

crypttab.5: crypttab.5.txt
	a2x -d manpage -f manpage crypttab.5.txt
	rm -f crypttab.5.xml

cryptotab.5: cryptotab.5.txt
	a2x -d manpage -f manpage cryptotab.5.txt
	rm -f cryptotab.5.xml

crypttab.5.html: crypttab.5.txt
	$(ASCIIDOC) crypttab.5.txt

cryptotab.5.html: cryptotab.5.txt
	$(ASCIIDOC) cryptotab.5.txt

install: crypttab.5 cryptotab.5
	install -d -m 755 $(DESTDIR)$(initrdscriptsdir)
	install -d -m 755 $(DESTDIR)$(initscriptdir)
	install -d -m 755 $(DESTDIR)$(pkglibdir)/checks
	install -d -m 755 $(DESTDIR)$(mandir)/man5
	install -m 755 boot.crypto $(DESTDIR)$(initscriptdir)
	install -m 755 boot.crypto-early $(DESTDIR)$(initscriptdir)
	install -m 755 boot.crypto.functions $(DESTDIR)$(pkglibdir)
	install -m 755 checks/vol_id $(DESTDIR)$(pkglibdir)/checks
	install -m 644 crypttab.5 $(DESTDIR)$(mandir)/man5
	install -m 644 cryptotab.5 $(DESTDIR)$(mandir)/man5
	install -m 644 /dev/null $(DESTDIR)$(sysconfdir)/cryptotab
	install -m 644 /dev/null $(DESTDIR)$(sysconfdir)/crypttab
	install -m 755 mkinitrd/setup-luks.sh $(DESTDIR)$(initrdscriptsdir)/setup-luks.sh
	install -m 755 mkinitrd/boot-luks.sh $(DESTDIR)$(initrdscriptsdir)/boot-luks.sh

html: crypttab.5.html cryptotab.5.html

.PHONY: install html
