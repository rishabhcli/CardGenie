Foundation Models
Enhance features in your by using the on-device model at the core of Apple Intelligence.
Overview
When you want to apply intelligent capabilities to your apps, you can use the same on-device foundation models that power Apple Intelligence to build and improve your features. For example, turn a hard-coded search suggestion list into a generated list of suggestions that is personalized to the moment.
As you begin working with generative models and prompt engineering, it’s important to keep design in mind. The HIG provides guidance and best practices to help you create apps that use generative models.
Define the data your app needs for precise output
To integrate generative technologies in your app, look to your app’s existing features for ideas. If your app offers people a way to submit restaurant reviews, the model can use custom data types to convert someone’s review into a scorecard that lets people visualize how positive the review was. Because you know the type of data your app wants, your custom data types help guide model output to fit your use case. Instead of writing parsing code, this allows you to think about the data your app needs to create a richer app experience.
And once you know the type of data your app needs, focus on writing prompts that produce better results. It takes time and practice to craft a good prompt, so try a variety of requests and test the output the model returns.
Create custom tools for your app
Tool calling allows a model to interact with the code you write to extend the model’s capabilities. When you prompt the model with tools, the model can determine whether a tool you provide is available to help complete the request. For example, you could write code in your app that scans the person’s calendar events for a dinner reservation, and populates a text to the invitees that includes the name of the restaurant, time of the reservation, and information for nearby parking. When the model encounters a prompt that requests dinner reservation information, it can call the code you write to get up to date information that it uses to complete the request.
Customize further with a custom adapter
For apps that contain tasks that need domain specialization, adapters provide a way to leverage your own training data. Adapters are small modules that you train to enhance — or adapt — the base model’s ability to perform a specific task. You write adapters using the Foundation Models Adapter Training Toolkit.


Create, optimize, and deploy models for on-device execution.
Overview
When the available intelligent frameworks or generative technologies don’t provide the features you need, Apple provides machine learning frameworks that help you:
Create models from your own training data.
Run generative models, stateful models, and transformer models efficiently.
Convert models from other training libraries to run on-device.
Preview your model’s behavior from sample data or live inputs.
Analayze the performance of your model in Xcode and Instruments.
Build models to analyze text, images, or other types of data your app needs. If you already have your own machine learning models, convert them to the Core ML model format and integrate them into your app. Apple also provides frameworks to help with highly demanding machine learning tasks that involve graphics and real-time signal processing.
As you design your models, it’s important to keep the intended experience of your app in mind. The HIG offers machine learning guidance and best practices to help you create apps that use machine learning.
Collect and prepare your data for training
When you create a new model the starting point is always the same — your training and testing data. The quality of your data determines the quality of your results, so choose data that reflects a wide variety of possibility for your training use case. For example, when you create an image classification model to recognize animals, begin by gathering at least 10 images per animal that best represent what you expect the model to see. Create ML supports several types of data sources, each with its own arrangement of files within a parent folder. In you parent folder, organize data into subfolders and use the folder name as your training label.
If you use the Create ML framework to programmatically create and train a model — like a text classifier that identifies the sentiment expressed in a sentence — prepare your data for training by using TabularData.
Build and train on-device models with no code
Many system frameworks can be extended or customized to your specific use case. If you’re working in a specialized domain that requires using your own data — or you want to extend the capabilities of an existing framework – the Create ML app makes it easier to adapt system models. For example, if you use the Sound Analysis framework and notice it can’t classify your sound, use the Create ML app to train a sound classification model that’s trained to identify your sound. After you train the model, load it with the Sound Analysis framework.
Built with the Create ML and Create ML Components frameworks, the Create ML app provides an approachable interface for creating models using your own data. In Xcode, choose Xcode > Open Developer Tool > Create ML. Choose a template that aligns with the task you want to customize, then provide your data, train, evaluate, and iterate on your model.
A screenshot of the Create ML app’s template selection screen.
After training your model, use the Create ML app to visualize and debug your annotations by clicking on the data source. The default view shows a distribution of your data, and the Explore page lets you see into specific object or class labels to visualize your annotations. The app provides you with a model that’s ready to integrate into your app with Core ML.
Model conversion and optimization
Bring any model to the device if you want to experiment with it or deploy it. All you need is the model to be in the Core ML format. Core ML is the go-to framework for deploying models on-device, and you can download and explore models that are already in the Core ML format to experiment with or use for your feature.
If you created a model using training libraries like MLX or PyTorch, use Core ML Tools to convert it to the Core ML format. Core ML Tools provides utilities and workflows for transforming trained models to the Core ML format. The workflows that Core ML Tools provide apply optimizations for on-device execution. Converting your model optimizes it for Apple devices, which requires less space on device, uses less power, and reduces latency when making predictions. Core ML Tools provides a number of compression techniques to help you optimize the model representation and parameters, while maintaining good accuracy.
When you have an optimized and prepared model, you’re ready to integrate it with system frameworks. For example, if your model performs image analysis, load the model with the Vision framework.
Analyze the performance of your model with Xcode
Evaluating the performance of models is an important task of machine learning. In Xcode, preview your model’s behavior by using sample data files or using the device’s camera and microphone. Review the performance of your model’s predictions directly from Xcode, or profile your app in Instruments to get a thorough performance analysis. After you add a model to your project, select it to get insights about the expected prediction latency, load times, and introspect where a particular operation is supported and run.
An Xcode screenshot that shows a selected model file. The UI shows the performance report for the Resnet50 image classification model with median times for prediction, load, and compilation. It also shows the compute unit mapping and that each unit ran on the Neural Engine.
To build a deeper understanding of the model you’re working with, Xcode allows you to visualize the structure of the full model architecture and dive into the details of any operation. This visualization helps you debug issues and find performance enhancing opportunities.
Model deployment and execution on device
You use Core ML to integrate and run your model directly into your app. At runtime, Core ML makes use of all available compute and optimizes task execution across CPU, GPU, and Neural Engine. There are several technologies that underly Core ML that are available when you need fine-grained control over machine learning task execution.
To sequence and integrate machine learning with demanding graphics workloads, use Core ML models with both Metal Performance Shaders Graph and Metal. MPS Graph enables you to sequence tasks with other workloads, which optimizes GPU utilization. Use MPS Graph to load your Core ML model or programmatically build, compile, and execute computational graphs.
When running real-time signal processing on the CPU, use the BNNS Graph API in Accelerate. BNNS Graph works with Core ML models to enable real-time and latency-sensitive inference on the CPU, along with strict control over memory allocations. Use the Graph Builder to create graphs of operations that allow for writing routines or even small machine learning models to run in real-time on the CPU.


Generating content and performing tasks with Foundation Models
Enhance the experience in your app by prompting an on-device large language model.
Overview
The Foundation Models framework lets you tap into the on-device large models at the core of Apple Intelligence. You can enhance your app by using generative models to create content or perform tasks. The framework supports language understanding and generation based on model capabilities.
For design guidance, see Human Interface Guidelines > Technologies > Generative AI.
Understand model capabilities
When considering features for your app, it helps to know what the on-device language model can do. The on-device model supports text generation and understanding that you can use to:
Capability
Prompt example
Summarize
“Summarize this article.”
Extract entities
“List the people and places mentioned in this text.”
Understand text
“What happens to the dog in this story?”
Refine or edit text
“Change this story to be in second person.”
Classify or judge text
“Is this text relevant to the topic ‘Swift’?”
Compose creative writing
“Generate a short bedtime story about a fox.”
Generate tags from text
“Provide two tags that describe the main topics of this text.”
Generate game dialog
“Respond in the voice of a friendly inn keeper.”
The on-device language model may not be suitable for handling all requests, like:
Capabilities to avoid
Prompt example
Do basic math
“How many b’s are there in bagel?”
Create code
“Generate a Swift navigation list.”
Perform logical reasoning
“If I’m at Apple Park facing Canada, what direction is Texas?”
The model can complete complex generative tasks when you use guided generation or tool calling. For more on handling complex tasks, or tasks that require extensive world-knowledge, see Generating Swift data structures with guided generation and Expanding generation with tool calling.
Check for availability
Before you use the on-device model in your app, check that the model is available by creating an instance of SystemLanguageModel with the default property.
Model availability depends on device factors like:
The device must support Apple Intelligence.
The device must have Apple Intelligence turned on in Settings.
Note
It can take some time for the model to download and become available when a person turns on Apple Intelligence.
Always verify model availability first, and plan for a fallback experience in case the model is unavailable.
struct GenerativeView: View {
    // Create a reference to the system language model.
    private var model = SystemLanguageModel.default


    var body: some View {
        switch model.availability {
        case .available:
            // Show your intelligence UI.
        case .unavailable(.deviceNotEligible):
            // Show an alternative UI.
        case .unavailable(.appleIntelligenceNotEnabled):
            // Ask the person to turn on Apple Intelligence.
        case .unavailable(.modelNotReady):
            // The model isn't ready because it's downloading or because of other system reasons.
        case .unavailable(let other):
            // The model is unavailable for an unknown reason.
        }
    }
}
Create a session
After confirming that the model is available, create a LanguageModelSession object to call the model. For a single-turn interaction, create a new session each time you call the model:
// Create a session with the system model.
let session = LanguageModelSession()
For a multiturn interaction — where the model retains some knowledge of what it produced — reuse the same session each time you call the model.
Provide a prompt to the model
A Prompt is an input that the model responds to. Prompt engineering is the art of designing high-quality prompts so that the model generates a best possible response for the request you make. A prompt can be as short as “hello”, or as long as multiple paragraphs. The process of designing a prompt involves a lot of exploration to discover the best prompt, and involves optimizing prompt length and writing style.
When thinking about the prompt you want to use in your app, consider using conversational language in the form of a question or command. For example, “What’s a good month to visit Paris?” or “Generate a food truck menu.”
Write prompts that focus on a single and specific task, like “Write a profile for the dog breed Siberian Husky”. When a prompt is long and complicated, the model takes longer to respond, and may respond in unpredictable ways. If you have a complex generation task in mind, break the task down into a series of specific prompts.
You can refine your prompt by telling the model exactly how much content it should generate. A prompt like, “Write a profile for the dog breed Siberian Husky” often takes a long time to process as the model generates a full multi-paragraph essay. If you specify “using three sentences”, it speeds up processing and generates a concise summary. Use phrases like “in a single sentence” or “in a few words” to shorten the generation time and produce shorter text.
// Generate a longer response for a specific command.
let simple = "Write me a story about pears."


// Quickly generate a concise response.
let quick = "Write the profile for the dog breed Siberian Husky using three sentences."
Provide instructions to the model
Instructions help steer the model in a way that fits the use case of your app. The model obeys prompts at a lower priority than the instructions you provide. When you provide instructions to the model, consider specifying details like:
What the model’s role is; for example, “You are a mentor,” or “You are a movie critic”.
What the model should do, like “Help the person extract calendar events,” or “Help the person by recommending search suggestions”.
What the style preferences are, like “Respond as briefly as possible”.
What the possible safety measures are, like “Respond with ‘I can’t help with that’ if you’re asked to do something dangerous”.
Use content you trust in instructions because the model follows them more closely than the prompt itself. When you initialize a session with instructions, it affects all prompts the model responds to in that session. Instructions can also include example responses to help steer the model. When you add examples to your prompt, you provide the model with a template that shows the model what a good response looks like.
Generate a response
To call the model with a prompt, call respond(to:options:) on your session. The response call is asynchronous because it may take a few seconds for the on-device foundation model to generate the response.
let instructions = """
    Suggest five related topics. Keep them concise (three to seven words) and make sure they \
    build naturally from the person's topic.
    """


let session = LanguageModelSession(instructions: instructions)


let prompt = "Making homemade bread"
let response = try await session.respond(to: prompt)
Note
A session can only handle a single request at a time, and causes a runtime error if you call it again before the previous request finishes. Check isResponding to verify the session is done processing the previous request before sending a new one.
Instead of working with raw string output from the model, the framework offers guided generation to generate a custom Swift data structure you define. For more information about guided generation, see Generating Swift data structures with guided generation.
When you make a request to the model, you can provide custom tools to help the model complete the request. If the model determines that a Tool can assist with the request, the framework calls your Tool to perform additional actions like retrieving content from your local database. For more information about tool calling, see Expanding generation with tool calling
Consider context size limits per session
The context window size is a limit on how much data the model can process for a session instance. A token is a chunk of text the model processes, and the system model supports up to 4,096 tokens. A single token corresponds to three or four characters in languages like English, Spanish, or German, and one token per character in languages like Japanese, Chinese, or Korean. In a single session, the sum of all tokens in the instructions, all prompts, and all outputs count toward the context window size.
If your session processes a large amount of tokens that exceed the context window, the framework throws the error LanguageModelSession.GenerationError.exceededContextWindowSize(_:). When you encounter the error, start a new session and try shortening your prompts. If you need to process a large amount of data that won’t fit in a single context window limit, break your data into smaller chunks, process each chunk in a separate session, and then combine the results.
For more information on managing the context window size, see TN3193: Managing the on-device foundation model’s context window.
Tune generation options and optimize performance
To get the best results for your prompt, experiment with different generation options. GenerationOptions affects the runtime parameters of the model, and you can customize them for every request you make.
// Customize the temperature to increase creativity.
let options = GenerationOptions(temperature: 2.0)


let session = LanguageModelSession()


let prompt = "Write me a story about coffee."
let response = try await session.respond(
    to: prompt,
    options: options
)
When you test apps that use the framework, use Xcode Instruments to understand more about the requests you make, like the time it takes to perform a request. When you make a request, you can access the Transcript entries that describe the actions the model takes during your LanguageModelSession.
See Also
Essentials
Improving the safety of generative model output
Create generative experiences that appropriately handle sensitive inputs and respect people.
Support languages and locales with Foundation Models
Generate content in the language people prefer when they interact with your app.
Adding intelligent app features with generative models
Build robust apps with guided generation and tool calling by adopting the Foundation Models framework.
class SystemLanguageModel
An on-device large language model capable of text generation tasks.
struct UseCase
A type that represents the use case for prompting.


Improving the safety of generative model output
Create generative experiences that appropriately handle sensitive inputs and respect people.
Overview
Generative AI models have powerful creativity, but with this creativity comes the risk of unintended or unexpected results. For any generative AI feature, safety needs to be an essential part of your design.
The Foundation Models framework has two base layers of safety, where the framework uses:
An on-device language model that has training to handle sensitive topics with care.
Guardrails that aim to block harmful or sensitive content, such as self-harm, violence, and adult materials, from both model input and output.
Because safety risks are often contextual, some harms might bypass both built-in framework safety layers. It’s vital to design additional safety layers specific to your app. When developing your feature, decide what’s acceptable or might be harmful in your generative AI feature, based on your app’s use case, cultural context, and audience.
For more information on designing generative AI experiences responsibly, see Human Interface Guidelines > Foundations > Generative AI.
Handle guardrail errors
When you send a prompt to the model, SystemLanguageModel.Guardrails check the input prompt and the model’s output. If either fails the guardrail’s safety check, the model session throws a LanguageModelSession.GenerationError.guardrailViolation(_:) error:
do {
    let session = LanguageModelSession()
    let topic = // A potentially harmful topic.
    let prompt = "Write a respectful and funny story about \(topic)."
    let response = try await session.respond(to: prompt)
} catch LanguageModelSession.GenerationError.guardrailViolation {
    // Handle the safety error.
}
If you encounter a guardrail violation error for any built-in prompt in your app, experiment with re-phrasing the prompt to determine which phrases are activating the guardrails, and avoid those phrases. If the error is thrown in response to a prompt created by someone using your app, give people a clear message that explains the issue. For example, you might say “Sorry, this feature isn’t designed to handle that kind of input” and offer people the opportunity to try a different prompt.
Handle model refusals
The on-device language model may not be suitable for handling all requests and may refuse requests for a topic. When you generate a string response, and the model refuses a request, it generates a message that begins with a refusal like “Sorry, I can’t help with”.
Design your app experience with refusal messages in mind and present the message to the person using your app. You might not be able to programmatically determine whether a string response is a normal response or a refusal, so design the experience to anticipate both. If it’s critical to determine whether the response is a refusal message, initialize a new LanguageModelSession and prompt the model to classify whether the string is a refusal.
When you use guided generation to generate Swift structures or types, there’s no placeholder for a refusal message. Instead, the model throws a LanguageModelSession.GenerationError.refusal(_:_:) error. When you catch the error, you can ask the model to generate a string refusal message:
do {
    let session = LanguageModelSession()
    let topic = ""  // A sensitive topic.
    let response = try session.respond(
        to: "List five key points about: \(topic)",
        generating: [String].self
    )
} catch LanguageModelSession.GenerationError.refusal(let refusal, _) {
    // Generate an explanation for the refusal.
    if let message = try? await refusal.explanation {
        // Display the refusal message.
    }
}
Display the explanation in your app to tell people why a request failed, and offer people the opportunity to try a different prompt. Retrieving an explanation message is asynchronous and takes time for the model to generate.
If you encounter a refusal message, or refusal error, for any built-in prompts in your app, experiment with re-phrasing your prompt to avoid any sensitive topics that might cause the refusal.
For more information about guided generation, see Generating Swift data structures with guided generation.
Build boundaries on input and output
Safety risks increase when a prompt includes direct input from a person using your app, or from an unverified external source, like a webpage. An untrusted source makes it difficult to anticipate what the input contains. Whether accidentally or on purpose, someone could input sensitive content that causes the model to respond poorly.
Tip
The more you can define the intended usage and outcomes for your feature, the more you can ensure generation works great for your app’s specific use cases. Add boundaries to limit out-of-scope usage and minimize low generation quality from out-of-scope uses.
Whenever possible, avoid open input in prompts and place boundaries for controlling what the input can be. This approach helps when you want generative content to stay within the bounds of a particular topic or task. For the highest level of safety on input, give people a fixed set of prompts to choose from. This gives you the highest certainty that sensitive content won’t make its way into your app:
enum TopicOptions {
    case family
    case nature
    case work 
}
let topicChoice = TopicOptions.nature
let prompt = """
    Generate a wholesome and empathetic journal prompt that helps \
    this person reflect on \(topicChoice)
    """
If your app allows people to freely input a prompt, placing boundaries on the output can also offer stronger safety guarantees. Using guided generation, create an enumeration to restrict the model’s output to a set of predefined options designed to be safe no matter what:
@Generable
enum Breakfast {
    case waffles
    case pancakes
    case bagels
    case eggs 
}
let session = LanguageModelSession()
let userInput = "I want something sweet."
let prompt = "Pick the ideal breakfast for request: \(userInput)"
let response = try await session.respond(to: prompt, generating: Breakfast.self)
Instruct the model for added safety
Consider adding detailed session Instructions that tell the model how to handle sensitive content. The language model prioritizes following its instructions over any prompt, so instructions are an effective tool for improving safety and overall generation quality. Use uppercase words to emphasize the importance of certain phrases for the model:
do {
    let instructions = """
        ALWAYS respond in a respectful way. \
        If someone asks you to generate content that might be sensitive, \
        you MUST decline with 'Sorry, I can't do that.'
        """
    let session = LanguageModelSession(instructions: instructions)
    let prompt = // Open input from a person using the app.
    let response = try await session.respond(to: prompt)
} catch LanguageModelSession.GenerationError.guardrailViolation {
    // Handle the safety error.
}
Note
A session obeys instructions over a prompt, so don’t include input from people or any unverified input in the instructions. Using unverified input in instructions makes your app vulnerable to prompt injection attacks, so write instructions with content you trust.
If you want to include open-input from people, instructions for safety are recommended. For an additional layer of safety, use a format string in normal prompts that wraps people’s input in your own content that specifies how the model should respond:
let userInput = // The input a person enters in the app.
let prompt = """
    Generate a wholesome and empathetic journal prompt that helps \
    this person reflect on their day. They said: \(userInput)
    """
Add a deny list of blocked terms
If you allow prompt input from people or outside sources, consider adding your own deny list of terms. A deny list is anything you don’t want people to be able to input to your app, including unsafe terms, names of people or products, or anything that’s not relevant to the feature you provide. Implement a deny list similarly to guardrails by creating a function that checks the input and the model output:
let session = LanguageModelSession()
let userInput = // The input a person enters in the app.
let prompt = "Generate a wholesome story about: \(userInput)"


// A function you create that evaluates whether the input 
// contains anything in your deny list.
if verifyText(prompt) { 
    let response = try await session.respond(to: prompt)
    
    // Compare the output to evaluate whether it contains anything in your deny list.
    if verifyText(response.content) { 
        return response 
    } else {
        // Handle the unsafe output.
    }
} else {
    // Handle the unsafe input.
}
A deny list can be a simple list of strings in your code that you distribute with your app. Alternatively, you can host a deny list on a server so your app can download the latest deny list when it’s connected to the network. Hosting your deny list allows you to update your list when you need to and avoids requiring a full app update if a safety issue arise.
Use permissive guardrail mode for sensitive content
The default SystemLanguageModel guardrails may throw a LanguageModelSession.GenerationError.guardrailViolation(_:) error for sensitive source material. For example, it may be appropriate for your app to work with certain inputs from people and unverified sources that might contain sensitive content:
When you want the model to tag the topic of conversations in a chat app when some messages contain profanity.
When you want to use the model to explain notes in your study app that discuss sensitive topics.
To allow the model to reason about sensitive source material, use permissiveContentTransformations when you initialize SystemLanguageModel:
let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
This mode only works for generating a string value. When you use guided generation, the framework runs the default guardrails against model input and output as usual, and generates LanguageModelSession.GenerationError.guardrailViolation(_:) and LanguageModelSession.GenerationError.refusal(_:_:)errors as usual.
Before you use permissive content mode, consider what’s appropriate for your audience. The session skips the guardrail checks in this mode, so it never throws a LanguageModelSession.GenerationError.guardrailViolation(_:) error when generating string responses.
However, even with the SystemLanguageModel guardrails off, the on-device system language model still has a layer of safety. For some content, the model may still produce a refusal message that’s similar to, “Sorry, I can’t help with.”
Create a risk assessment
Conduct a risk assessment to proactively address what might go wrong. Risk assessment is an exercise that helps you brainstorm potential safety risks in your app and map each risk to an actionable mitigation. You can write a risk assessment in any format that includes these essential elements:
List each AI feature in your app.
For each feature, list possible safety risks that could occur, even if they seem unlikely.
For each safety risk, score how serious the harm would be if that thing occurred, from mild to critical.
For each safety risk, assign a strategy for how you’ll mitigate the risk in your app.
For example, an app might include one feature with the fixed-choice input pattern for generation and one feature with the open-input pattern for generation, which is higher safety risk:
Feature
Harm
Severity
Mitigation
Player can input any text to chat with nonplayer characters in the coffee shop.
A character might respond in an insensitive or harmful way.
Critical
Instructions and prompting to steer characters responses to be safe; safety testing.
Image generation of an imaginary dream customer, like a fairy or a frog.
Generated image could look weird or scary.
Mild
Include in the prompt examples of images to generate that are cute and not scary; safety testing.
Player can make a coffee from a fixed menu of options.
None identified.
Generate a review of the coffee the player made, based on the customer’s order.
Review could be insulting.
Moderate
Instructions and prompting to encourage posting a polite review; safety testing.
Besides obvious harms, like a poor-quality model output, think about how your generative AI feature might affect people, including real-world scenarios where someone might act based on information generated by your app.
Write and maintain safety tests
Although most people will interact with your app in respectful ways, it’s important to anticipate possible failure modes where certain input or contexts could cause the model to generate something harmful. Especially if your app takes input from people, test your experience’s safety on input like:
Input that is nonsensical, snippets of code, or random characters.
Input that includes sensitive content.
Input that includes controversial topics.
Vague or unclear input that could be misinterpreted.
Create a list of potentially harmful prompt inputs that you can run as part of your app’s tests. Include every prompt in your app — even safe ones — as part of your app testing. For each prompt test, log the timestamp, full input prompt, the model’s response, and whether it activates any built-in safety or mitigations you’ve included in your app. When starting out, manually read the model’s response on all tests to ensure it meets your design and safety goals. To scale your tests, consider using a frontier LLM to auto-grade the safety of each prompt. Building a test pipeline for prompts and safety is a worthwhile investment for tracking changes in how your app responds over time.
Someone might purposefully attempt to break your feature or produce bad output — especially someone who won’t be harmed by their actions. But, keep in mind that it’s very important to identify cases where someone might accidentally be harmed during normal app use.
Tip
Prioritize protecting people using your app with good intentions. Accidental safety failures often only occur in specific contexts, which make them hard to identify during testing. Test for a longer series of interactions, and test for inputs that could become sensitive only when combined with other aspects of your app.
Don’t engage in any testing that could cause you or others harm. Apple’s built-in responsible AI and safety measures, like safety guardrails, are built by experts with extensive training and support. These built-in measures aim to block egregious harms, allowing you to focus on the borderline harmful cases that need your judgement. Before conducting any safety testing, ensure that you’re in a safe location and that you have the health and well-being support you need.
Report safety concerns
Somewhere in your app, it’s important to include a way that people can report potentially harmful content. Continuously monitor the feedback you receive, and be responsive to quickly handling any safety issues that arise. If someone reports a safety concern that you believe isn’t being properly handled by Apple’s built-in guardrails, report it to Apple with Feedback Assistant.
The Foundation Models framework offers utilities for feedback. Use LanguageModelFeedback to retrieve language model session transcripts from people using your app. After collecting feedback, you can serialize it into a JSON file and include it in the report you send with Feedback Assistant.
Monitor safety for model or guardrail updates
Apple releases updates to the system model as part of regular OS updates. If you participate in the developer beta program you can test your app with new model version ahead of people using your app. When the model updates, it’s important to re-run your full prompt tests in addition to your adversarial safety tests because the model’s response may change. Your risk assessment can help you track any change to safety risks in your app.
Apple may update the built-in guardrails at any time outside of the regular OS update cycle. This is done to rapidly respond, for example, to reported safety concerns that require a fast response. Include all of the prompts you use in your app in your test suite, and run tests regularly to identify when prompts start activating the guardrails.
See Also
Essentials
Generating content and performing tasks with Foundation Models
Enhance the experience in your app by prompting an on-device large language model.
Support languages and locales with Foundation Models
Generate content in the language people prefer when they interact with your app.
Adding intelligent app features with generative models
Build robust apps with guided generation and tool calling by adopting the Foundation Models framework.
class SystemLanguageModel
An on-device large language model capable of text generation tasks.
struct UseCase
A type that represents the use case for prompting.


Article
Support languages and locales with Foundation Models
Generate content in the language people prefer when they interact with your app.
Overview
The on-device system language model is multilingual, which means the same model understands and generates text in any language that Apple Intelligence supports. The model supports using different languages for prompts, instructions, and the output that the model produces.
When you enhance your app with multilingual support, generate content in the language people prefer to use when they interact with your app by:
Prompting the model with the language you prefer.
Including the target language for your app in the instructions you provide the model.
Determining the language or languages a person wants to use when they interact with your app.
Gracefully handling languages that Apple Intelligence doesn’t support.
For more information about the languages and locales that Apple Intelligence supports, see the “Supported languages” section in How to get Apple Intelligence.
Prompt the model in the language you prefer
Write your app’s built-in prompts in the language with which you normally write code, if Apple Intelligence supports that language. Translate your prompts into a supported language if your preferred language isn’t supported. In the code below, all inputs need to be in supported language for the model to understand, including all Generable types and descriptions:
@Generable(description: "Basic profile information about a cat")
struct CatProfile {
    var name: String


    @Guide(description: "The age of the cat", .range(0...20))
    var age: Int


    @Guide(description: "One sentence about this cat's personality")
    var profile: String
}


#Playground {
    let response = try await LanguageModelSession().respond(
        to: "Generate a rescue cat",
        generating: CatProfile.self
    )
}
Because the framework treats Generable types as model inputs, the names of properties like age or profile are just as important as the @Guide descriptions for helping the model understand your request.
Check a person’s language settings for your app
People can use the Settings app on their device to configure the language they prefer to use on a per-app basis, which might differ from their default language. If your app supports a language that Apple Intelligence doesn’t, you need to verify that the current language setting of your app is supported before you call the model. Keep in mind that language support improves over time in newer model and OS versions. Thus, someone using your app with an older OS may not have the latest language support.
Before you call the model, run supportsLocale(_:) to verify the support for a locale. By default, the method uses current, which takes into account a person’s current language and app-specific settings. This method returns true if the model supports this locale, or if this locale is considered similar enough to a supported locale, such as en-AU and en-NZ:
if SystemLanguageModel.default.supportsLocale() {
    // Language is supported.
}
For advanced use cases where you need full language support details, use supportedLanguages to retrieve a list of languages supported by the on-device model.
Handle an unsupported language or locale errors
When you call respond(to:options:) on a LanguageModelSession, the Foundation Models framework checks the language or languages of the input prompt text, and whether your prompt asks the model to respond in any specific language or languages. If the model detects a language it doesn’t support, the session throws LanguageModelSession.GenerationError.unsupportedLanguageOrLocale(_:). Handle the error by communicating to the person using your app that a language in their request is unsupported.
If your app supports languages or locales that Apple Intelligence doesn’t, help people that use your app by:
Explaining that their language isn’t supported by Apple Intelligence in your app.
Disabling your Foundation Models framework feature.
Providing an alternative app experience, if possible.
Important
Guardrails for model input and output safety are only for supported languages and locales. If a prompt contains sensitive content in an unsupported language, which typically is a short phrase mixed-in with text in a supported language, it might not throw a LanguageModelSession.GenerationError.unsupportedLanguageOrLocale(_:) error. If unsupported-language detection fails, the guardrails may also fail to flag that short, unsupported content. For more on guardrails, see Improving the safety of generative model output.
Use Instructions to set the locale and language
For locales other than United States English, you can improve response quality by telling the model which locale to use by detailing a set of Instructions. Start with the exact phrase in English. This special phrase comes from the model’s training, and reduces the possibility of hallucinations in multilingual situations:
func localeInstructions(for locale: Locale = Locale.current) -> String {
    if Locale.Language(identifier: "en_US").isEquivalent(to: locale.language) {
        // Skip the locale phrase for U.S. English.
        return "" 
    } else {
        // Specify the person's locale with the exact phrase format.
        return "The person's locale is \(locale.identifier)."
    }
}
After you set the locale in Instructions, you may need to explicitly set the model output language. By default, the model responds in the language or languages of its inputs. If your app supports multiple languages, prompts that you write and inputs from people using your app might be in different languages. For example, if you write your built-in prompts in Spanish, but someone using your app writes inputs in Dutch, the model may respond in either or both languages.
Use Instructions to explicity tell the model which language or languages with witch it needs to respond. You can phrase this request in different ways, for example: “You MUST respond in Italian” or “You MUST respond in Italian and be mindful of Italian spelling, vocabulary, entities, and other cultural contexts of Italy.” These instructions can be in the language you prefer.
let session = LanguageModelSession(
    instructions: "You MUST respond in U.S. English."
)
let prompt = // A prompt that contains Spanish and Italian.
let response = try await session.respond(to: prompt)
Finally, thoroughly test your instructions to ensure the model is responding in the way you expect. If the model isn’t following your instructions, try capitalized words like “MUST” or “ALWAYS” to strengthen your instructions.
See Also
Essentials
Generating content and performing tasks with Foundation Models
Enhance the experience in your app by prompting an on-device large language model.
Improving the safety of generative model output
Create generative experiences that appropriately handle sensitive inputs and respect people.
Adding intelligent app features with generative models
Build robust apps with guided generation and tool calling by adopting the Foundation Models framework.
class SystemLanguageModel
An on-device large language model capable of text generation tasks.
struct UseCase
A type that represents the use case for prompting.

Note
This sample code project is associated with WWDC25 session 259: Code-along: Add Intelligence to your App using the Foundation Models framework.
Configure the sample code project
To configure the sample code project, do the following:
Open the sample with the latest version of Xcode.
In Xcode, set the developer team for the app target to let Xcode automatically manage the provisioning profile. For more information, see Set the bundle ID and Assign the project to a team.
In the developer portal, enable the WeatherKit app service for your bundle ID to access weather information.
See Also
Essentials
Generating content and performing tasks with Foundation Models
Enhance the experience in your app by prompting an on-device large language model.
Improving the safety of generative model output
Create generative experiences that appropriately handle sensitive inputs and respect people.
Support languages and locales with Foundation Models
Generate content in the language people prefer when they interact with your app.
class SystemLanguageModel
An on-device large language model capable of text generation tasks.
struct UseCase
A type that represents the use case for prompting.
