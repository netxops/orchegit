--!/usr/bin/lua

email_config = resource.email.new("email_config")
email_config.userName = "41533337@qq.com"
email_config.password = "ayazngvuhpfdbhgc"
email_config.from = "dd <41533337@qq.com>"
email_config.to = "chao.huang@biz-united.com.cn"
email_config.subject = "golang send email demo"
email_config.port = 25
email_config.contentType = "text"
email_config.content = "Hello World!!!!!"
email_config.host = "smtp.qq.com"
email_config.sender = email_config.userName

catalog:add(email_config)
