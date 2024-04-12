package org.jruby8178;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@SpringBootApplication
@ComponentScan("no.datek.slim")
public class MyApplication {
    @RequestMapping("/")
    String home() {
        return "index";
    }

    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
