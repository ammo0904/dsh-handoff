
__DOMAIN__ {
	encode zstd gzip
	route {
		handle_path /login/* {
			root * /data/login
			file_server
		}
		reverse_proxy 127.0.0.1:3080 {
			transport http {
				read_timeout 600s
				write_timeout 600s
			}
		}
	}
	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		-Server
	}
}
