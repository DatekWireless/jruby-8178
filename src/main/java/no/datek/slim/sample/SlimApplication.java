package no.datek.slim.sample;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@SpringBootApplication
@ComponentScan("no.datek.slim")
public class SlimApplication {
    @RequestMapping({"/", "{id}"})
    String home(@PathVariable(required = false) Integer id, Model model) {
        model.addAttribute("id", id);
        return "index";
    }

    public static void main(String[] args) {
        SpringApplication.run(SlimApplication.class, args);
    }
}
