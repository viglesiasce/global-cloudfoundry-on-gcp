@RestController
class ThisWillActuallyRun {

    @RequestMapping("/")
    String home() {
        def env = System.getenv()
        return "Hello World from the " + env['REGION'] + " region!"
    }

}
