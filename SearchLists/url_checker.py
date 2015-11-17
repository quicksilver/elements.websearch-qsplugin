import re
import aiohttp, asyncio

URL_re = re.compile(r"""(?:href=")(.*?)(?:">)""")

@asyncio.coroutine
def get_page(url):
	try:
		r = yield from aiohttp.get(url)
		yield from r.release()
		if url.startswith("http://"):
			url = url.replace("http://", "https://")
			r = yield from aiohttp.get(url)
			yield from r.release()
			print("Switch %s to HTTPS" % url)
	except Exception as e:
		print("%s: %s" % (url, e))

def main():
	with open("web-search-list-full.html", "r") as f:
		urls = URL_re.findall(f.read())
	
	loop = asyncio.get_event_loop()
	loop.run_until_complete(asyncio.wait([get_page(u) for u in urls]))

if __name__ == "__main__":
	main()