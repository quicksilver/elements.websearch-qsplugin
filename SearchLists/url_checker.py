import re
import ssl, urllib2

URL_re = re.compile(r"""(?:href=")(.*?)(?:">)""")

def main():
	with open("web-search-list-full.html", "r") as f:
		urls = URL_re.findall(f.read())
	for url in urls:
		try:
			urllib2.urlopen(url.replace("***", "abc"))
		except (ssl.CertificateError, urllib2.URLError) as e:
			print "Could not open %s:\n%s" % (url, e)

if __name__ == "__main__":
	main()
