@RestController
class ThisWillActuallyRun {

    @RequestMapping("/")
    String home() {
        return "Hello World from the East!<br>"
    }

}
