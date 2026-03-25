import 'dart:convert';
import 'package:communiq/models/communiq_level.dart';

class StaticLevels {
  static const String jsonString = '''
{
  "app": "Communiq",
  "version": "1.0",
  "total_levels": 50,
  "levels": [
    {
      "id": 1,
      "title": "Introducing yourself",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Introduce yourself in class", "prompt": "You're a new student. Tell the class your name, where you're from, and one hobby." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Introduce yourself in a job interview", "prompt": "You've just sat down with an interviewer. Give a confident self-introduction in under 90 seconds." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Introduce yourself at a professional networking event", "prompt": "You're at an industry mixer. Introduce yourself to a group of strangers and make it memorable." }
      ]
    },
    {
      "id": 2,
      "title": "Greeting people",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Greet a new classmate", "prompt": "Say hello to someone sitting next to you for the first time. Start a short, friendly conversation." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Greet a client at a meeting", "prompt": "A client has arrived at your office. Welcome them warmly and make them feel comfortable." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Greet a senior executive at a formal event", "prompt": "You're at a company gala and the CEO walks toward you. How do you greet and engage them?" }
      ]
    },
    {
      "id": 3,
      "title": "Small talk",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Chat about the weather with a neighbour", "prompt": "You bump into your neighbour. Keep a light conversation going for at least one minute." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Small talk before a meeting starts", "prompt": "You arrive 5 minutes early to a work meeting. Make small talk with a colleague you don't know well." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Keep a conversation alive at a dinner party", "prompt": "You're seated next to someone you've just met. Keep engaging small talk going throughout the meal." }
      ]
    },
    {
      "id": 4,
      "title": "Asking for help",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Ask a classmate to explain a topic", "prompt": "You didn't understand a concept in class. Politely ask a peer to explain it to you." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Ask your manager for guidance", "prompt": "You're stuck on a work task. Request help from your manager without sounding incompetent." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Ask a senior expert for mentorship", "prompt": "You want guidance from someone highly respected in your field. How do you make the ask?" }
      ]
    },
    {
      "id": 5,
      "title": "Saying thank you",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Thank a friend for a favour", "prompt": "A friend helped you move flats. Express genuine gratitude in a short conversation." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Thank a colleague for covering your work", "prompt": "A teammate handled your tasks while you were sick. Thank them sincerely in person." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Write and deliver a thank-you speech", "prompt": "You're receiving an award at college. Deliver a 1-minute thank-you speech to your audience." }
      ]
    },
    {
      "id": 6,
      "title": "Apologising",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Apologise for being late to class", "prompt": "You walk in 10 minutes late. Apologise to your teacher and classmates briefly but sincerely." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Apologise for missing a deadline at work", "prompt": "You missed an important submission. Apologise to your manager and explain your plan going forward." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Apologise to a client for a serious error", "prompt": "A mistake on your team's part cost a client time and money. Lead the apology conversation." }
      ]
    },
    {
      "id": 7,
      "title": "Giving directions",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Direct someone to the library on campus", "prompt": "A new student asks you how to get to the library. Give clear spoken directions." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Guide a visitor around your office building", "prompt": "A guest has arrived for a meeting in a different department. Walk them through the building verbally." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Give directions to a tourist in an unfamiliar area", "prompt": "A tourist asks you for directions to a landmark but you're not fully sure of the route. Navigate this confidently." }
      ]
    },
    {
      "id": 8,
      "title": "Making requests",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Ask a classmate to share notes", "prompt": "You missed a lecture. Politely ask a classmate if you can borrow their notes." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Request a deadline extension from a professor", "prompt": "You need more time on an assignment. Make a clear and respectful request to your professor." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Negotiate a raise with your manager", "prompt": "You believe you deserve a salary increase. Make the case clearly and confidently in a 1:1 meeting." }
      ]
    },
    {
      "id": 9,
      "title": "Disagreeing politely",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Disagree with a classmate's opinion", "prompt": "Your classmate says something you don't agree with. Respectfully share your different view." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Challenge an idea in a team meeting", "prompt": "Someone proposes a plan you think won't work. How do you push back without damaging the relationship?" },
        { "stage": 3, "difficulty": "Hard", "scenario": "Disagree with your manager's decision", "prompt": "Your manager makes a call you strongly disagree with. Voice your concern professionally and constructively." }
      ]
    },
    {
      "id": 10,
      "title": "Giving opinions",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Share your opinion on a book in class", "prompt": "Your teacher asks what you thought of the assigned reading. Give a clear, structured opinion." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Give feedback on a colleague's presentation", "prompt": "A teammate just presented their work. Offer honest, constructive feedback in a team setting." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Present your point of view in a debate", "prompt": "You're in a formal debate. Argue your position convincingly while responding to counterpoints." }
      ]
    },
    {
      "id": 11,
      "title": "Making phone calls",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Call to check your exam results", "prompt": "You need to call the admin office to ask about your results. What do you say?" },
        { "stage": 2, "difficulty": "Medium", "scenario": "Call a client to confirm a meeting", "prompt": "You need to confirm a client appointment over the phone. Keep it professional and concise." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Handle a difficult customer complaint call", "prompt": "An angry customer calls to complain. De-escalate the situation and resolve it professionally." }
      ]
    },
    {
      "id": 12,
      "title": "Writing emails",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Email your professor about an absence", "prompt": "You missed class due to illness. Write a short, polite email to your professor explaining why." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Email a client to follow up on a proposal", "prompt": "You sent a proposal a week ago and haven't heard back. Write a professional follow-up email." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Write a formal complaint email", "prompt": "A service you paid for was not delivered properly. Write a firm but professional complaint email." }
      ]
    },
    {
      "id": 13,
      "title": "Job interviews",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Answer 'Tell me about yourself'", "prompt": "You're in an interview. Give a clear, engaging answer to the classic opener." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Explain a gap in your CV", "prompt": "The interviewer notices a gap in your work history. Address it confidently and honestly." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Handle a stress interview", "prompt": "The interviewer is deliberately challenging every answer you give. Stay composed and respond effectively." }
      ]
    },
    {
      "id": 14,
      "title": "Presentations",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Present a 2-minute summary to your class", "prompt": "Give a brief presentation on a topic of your choice to your classmates." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Present a project update to your team", "prompt": "Brief your team on where a project stands, what's been done, and what's next." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Present to senior leadership", "prompt": "You're presenting a business proposal to the leadership team. Deliver it with confidence and handle their questions." }
      ]
    },
    {
      "id": 15,
      "title": "Active listening",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Listen and summarise a classmate's story", "prompt": "Your classmate tells you about their weekend. Listen carefully and summarise it back to them." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Listen actively in a team briefing", "prompt": "Your manager gives a detailed project briefing. Demonstrate active listening and ask one follow-up question." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Listen and respond to a distressed colleague", "prompt": "A colleague comes to you visibly upset about a work issue. Show empathy and help them feel heard." }
      ]
    },
    {
      "id": 16,
      "title": "Negotiating",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Negotiate a group project role", "prompt": "Your group is dividing tasks and you want a specific role. Make your case fairly." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Negotiate a project deadline with a client", "prompt": "The client wants results faster than is realistic. Negotiate a timeline that works for both sides." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Negotiate a business contract", "prompt": "You're in a formal negotiation over contract terms. Navigate the discussion strategically." }
      ]
    },
    {
      "id": 17,
      "title": "Giving a compliment",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Compliment a friend's new look", "prompt": "Your friend has a new haircut. Give a genuine, natural compliment." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Compliment a colleague's work in a meeting", "prompt": "A teammate delivered excellent work. Acknowledge it publicly in a team meeting." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Give a formal appreciation speech", "prompt": "At a company event, you're asked to say a few words appreciating a long-serving team member." }
      ]
    },
    {
      "id": 18,
      "title": "Refusing politely",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Decline an invitation from a friend", "prompt": "A friend invites you to a party you can't attend. Say no politely without hurting their feelings." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Turn down an extra task at work", "prompt": "Your manager asks you to take on another project when you're already at capacity. How do you decline?" },
        { "stage": 3, "difficulty": "Hard", "scenario": "Reject a business proposal", "prompt": "A vendor pitches you something that's not a fit. Decline professionally while keeping the relationship intact." }
      ]
    },
    {
      "id": 19,
      "title": "Talking about your day",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Tell a friend how your day went", "prompt": "Recount your day to a friend in a natural, engaging way — highs and lows included." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Give a daily standup update at work", "prompt": "In your team's standup meeting, share what you did yesterday, today's plan, and any blockers." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Debrief a difficult day to a senior mentor", "prompt": "You had a stressful, complex day. Articulate it clearly and ask for advice professionally." }
      ]
    },
    {
      "id": 20,
      "title": "Telling stories",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Tell a funny story to friends", "prompt": "Share a funny thing that happened to you recently. Keep your audience engaged throughout." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Tell a professional story in an interview (STAR method)", "prompt": "Use the Situation–Task–Action–Result format to tell a story about a challenge you overcame at work." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Tell a compelling story in a public speech", "prompt": "You're speaking to 50 people. Open with a story that draws the audience in immediately." }
      ]
    },
    {
      "id": 21,
      "title": "Asking questions",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Ask questions to understand a new concept", "prompt": "You're confused by something in class. Ask your teacher two clear, specific questions." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Ask probing questions in a business meeting", "prompt": "You're in a client discovery meeting. Ask questions that uncover their real needs." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Ask questions in a panel interview", "prompt": "You're on a panel with 4 interviewers. Ask them questions that show intelligence and genuine interest." }
      ]
    },
    {
      "id": 22,
      "title": "Expressing emotions",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Tell a friend you're feeling stressed", "prompt": "You're overwhelmed with exams. Open up to a trusted friend about how you're feeling." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Express frustration professionally at work", "prompt": "A situation at work has been bothering you. Communicate your feelings to your manager constructively." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Handle emotions in a difficult conversation", "prompt": "You're in a charged discussion where emotions are running high. Stay calm and keep the talk productive." }
      ]
    },
    {
      "id": 23,
      "title": "Describing things",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Describe your hometown to someone who's never been", "prompt": "Paint a picture of your city or town for someone hearing about it for the first time." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Describe a product to a potential buyer", "prompt": "You work in sales. Describe your product's features and benefits to an interested customer." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Describe a complex technical concept to a non-expert", "prompt": "Explain a technical idea from your field to someone who has no background in it." }
      ]
    },
    {
      "id": 24,
      "title": "Handling criticism",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Receive feedback on a class assignment", "prompt": "Your teacher gives you critical feedback on your work. Respond gracefully and ask how to improve." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Handle negative feedback in a performance review", "prompt": "Your manager points out areas you're underperforming. Respond professionally and constructively." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Respond to public criticism", "prompt": "Someone criticises your work in front of a group. How do you respond calmly and professionally?" }
      ]
    },
    {
      "id": 25,
      "title": "Motivating others",
      "category": "Leadership",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Encourage a friend who's feeling low", "prompt": "Your friend is discouraged and thinking of quitting something important to them. Lift their spirits." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Motivate your team before a tough deadline", "prompt": "Your team is exhausted and morale is low. Give a short pep talk before a critical sprint." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Deliver an inspiring speech to a large group", "prompt": "You're addressing 100 people who are struggling. Deliver a 2-minute speech that genuinely motivates them." }
      ]
    },
    {
      "id": 26,
      "title": "Leading a meeting",
      "category": "Leadership",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Chair a study group session", "prompt": "You're leading a group revision session. Open it, keep everyone on track, and close it effectively." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Facilitate a team brainstorming meeting", "prompt": "Lead a 20-minute brainstorming session, draw out ideas from quiet participants, and summarise outcomes." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Run a high-stakes board meeting", "prompt": "You're presenting to and facilitating a meeting with senior stakeholders. Manage time, conflict, and decisions." }
      ]
    },
    {
      "id": 27,
      "title": "Resolving conflict",
      "category": "Leadership",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Resolve a disagreement between friends", "prompt": "Two friends in your group are in conflict. Mediate the situation calmly and fairly." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Resolve a dispute between team members", "prompt": "Two colleagues aren't getting along and it's affecting the team. Step in and help resolve it." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Mediate a formal workplace dispute", "prompt": "You've been asked to mediate a serious conflict between two departments. Handle it professionally." }
      ]
    },
    {
      "id": 28,
      "title": "Persuading others",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Persuade your friends to try a new restaurant", "prompt": "Convince your group of friends to try a cuisine they're hesitant about." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Persuade a manager to approve your idea", "prompt": "You have an idea that could improve a process at work. Make a persuasive case for it." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Pitch to investors", "prompt": "You're pitching a startup idea to a panel of investors. Persuade them your idea is worth funding." }
      ]
    },
    {
      "id": 29,
      "title": "Giving instructions",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Explain a game's rules to a friend", "prompt": "Teach someone a game or activity they've never tried. Give clear, step-by-step instructions." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Onboard a new team member", "prompt": "A new joiner has arrived. Walk them through their first-week tasks clearly and helpfully." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Brief a team on a complex new process", "prompt": "Your team needs to adopt a new system. Explain it clearly, anticipate confusion, and answer questions." }
      ]
    },
    {
      "id": 30,
      "title": "Talking about goals",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Share your goals with a friend", "prompt": "Tell a close friend what you want to achieve in the next year and why it matters to you." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Discuss career goals in a performance review", "prompt": "Your manager asks where you see yourself in 3 years. Give a clear, ambitious, and realistic answer." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Present your vision to a leadership team", "prompt": "You're asked to share your 5-year vision for your department. Make it compelling and credible." }
      ]
    },
    {
      "id": 31,
      "title": "Discussing current events",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Talk about a news story with a friend", "prompt": "Share your thoughts on a recent news event. Keep it balanced and invite the other person's views." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Discuss industry news with a colleague", "prompt": "A relevant development has happened in your industry. Discuss its implications with a colleague." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Comment on a controversial topic in a group", "prompt": "A heated topic comes up at a gathering. Share your view thoughtfully without causing offence." }
      ]
    },
    {
      "id": 32,
      "title": "Talking about hobbies",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Tell a classmate about your favourite hobby", "prompt": "Describe something you love doing in your free time in an engaging way." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Connect over shared interests in a networking setting", "prompt": "You discover a shared hobby with someone at a professional event. Use it to build rapport." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Speak passionately about your hobby to a skeptical audience", "prompt": "You're talking to people who don't share your interest. Get them curious and engaged." }
      ]
    },
    {
      "id": 33,
      "title": "Using formal language",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Write a formal request to your college admin", "prompt": "You need a letter confirming your enrolment. Write a formal request email." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Speak formally in a board meeting", "prompt": "You're presenting to senior leadership. Use precise, formal language throughout your delivery." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Draft a formal press statement", "prompt": "Your organisation needs to issue a statement on a sensitive topic. Write it with care and formality." }
      ]
    },
    {
      "id": 34,
      "title": "Using informal language",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Chat casually with a new classmate", "prompt": "Strike up a relaxed, friendly conversation with someone new in class." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Use casual English with a team during a fun outing", "prompt": "You're at a team lunch. Keep the tone light and conversational — no office jargon." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Switch fluidly from formal to informal in one conversation", "prompt": "A meeting with a client ends and you all go for a coffee. Shift your language register naturally." }
      ]
    },
    {
      "id": 35,
      "title": "Interviewing someone",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Interview a classmate for a class project", "prompt": "You need to gather information from a peer. Conduct a short structured interview." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Interview a job candidate", "prompt": "You're on the hiring side. Conduct a professional, fair, and insightful job interview." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Interview a senior expert for a research piece", "prompt": "You're speaking with a well-known figure in your field. Ask smart, probing questions and keep them engaged." }
      ]
    },
    {
      "id": 36,
      "title": "Talking on panels",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Answer a question on a student panel", "prompt": "You're on a panel at a college event. Answer a question confidently in front of an audience." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Represent your company on an industry panel", "prompt": "You're a panelist at a conference. Share your company's perspective on a sector trend." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Moderate a live panel discussion", "prompt": "You're the moderator for a panel of 4 experts. Keep the discussion flowing, balanced, and engaging." }
      ]
    },
    {
      "id": 37,
      "title": "Talking about achievements",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Tell a friend about something you're proud of", "prompt": "Share a recent achievement with a friend. Be proud but not boastful." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Highlight achievements in a performance review", "prompt": "Walk your manager through your top 3 achievements from the past 6 months with evidence." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Present a case study of your success to a client", "prompt": "A potential client wants to know what you've achieved before. Present a compelling success story." }
      ]
    },
    {
      "id": 38,
      "title": "Welcoming guests",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Welcome a guest to your home", "prompt": "A friend is visiting your place for the first time. Make them feel warm and comfortable." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Welcome new employees at an orientation", "prompt": "You're hosting a group of new joiners. Welcome them warmly and set a positive tone." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Welcome VIP guests at a formal event", "prompt": "You're the host at a company gala with senior guests. Open the event with a polished welcome address." }
      ]
    },
    {
      "id": 39,
      "title": "Making suggestions",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Suggest a movie to watch with friends", "prompt": "Your group can't decide what to watch. Make a recommendation and explain why they'll enjoy it." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Suggest an improvement in a team meeting", "prompt": "You notice a process that could be done better. Raise it constructively in a group setting." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Propose a strategic initiative to leadership", "prompt": "You've identified a significant opportunity. Make a clear, structured proposal to the leadership team." }
      ]
    },
    {
      "id": 40,
      "title": "Clarifying misunderstandings",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Clarify what you meant after being misunderstood by a friend", "prompt": "Your friend took something you said the wrong way. Calmly explain what you actually meant." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Clarify a miscommunication with a client", "prompt": "A client misunderstood the scope of your work. Correct the misunderstanding professionally." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Clear up a public misunderstanding", "prompt": "Something you said in a meeting has been misinterpreted by multiple people. Address it clearly and diplomatically." }
      ]
    },
    {
      "id": 41,
      "title": "Networking",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Connect with someone at a college career fair", "prompt": "You're at a career fair. Approach a recruiter, introduce yourself, and ask about opportunities." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Work the room at a professional mixer", "prompt": "You're at a networking event. Move between conversations and leave a strong impression on 3 people." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Build a meaningful connection with a senior leader", "prompt": "You've been introduced to someone very senior and influential. Make the conversation count." }
      ]
    },
    {
      "id": 42,
      "title": "Delivering bad news",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Tell a friend disappointing news", "prompt": "You have to tell a friend something they won't want to hear. Do it with care and empathy." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Inform a client of a delay", "prompt": "The project will be delivered late. Call or meet the client and deliver the news professionally." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Announce redundancies to a team", "prompt": "You need to inform your team that roles are being cut. Handle the conversation with honesty and compassion." }
      ]
    },
    {
      "id": 43,
      "title": "Following up",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Follow up with a classmate on a shared task", "prompt": "A group task is overdue and one person hasn't delivered. Follow up politely but clearly." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Follow up with a client after a meeting", "prompt": "You had a productive client meeting. Send a follow-up that summarises key points and next steps." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Chase a decision from a senior stakeholder", "prompt": "A key decision from leadership has been pending for weeks. Follow up assertively but respectfully." }
      ]
    },
    {
      "id": 44,
      "title": "Discussing money",
      "category": "Professional",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Split a bill with friends", "prompt": "You're out at dinner and sorting who owes what. Handle the conversation naturally and without awkwardness." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Discuss project budget with a manager", "prompt": "You need more budget to complete a project. Make the case clearly with numbers and reasoning." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Negotiate pricing with a vendor", "prompt": "A supplier has quoted above your budget. Negotiate the price down while keeping the relationship positive." }
      ]
    },
    {
      "id": 45,
      "title": "Talking about culture",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Share something interesting about your culture with a classmate", "prompt": "A foreign exchange student wants to learn about where you're from. What do you share?" },
        { "stage": 2, "difficulty": "Medium", "scenario": "Navigate a cultural difference at work", "prompt": "A cultural misunderstanding has occurred with a colleague from a different background. Address it sensitively." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Present a cross-cultural perspective in a business setting", "prompt": "You're working with an international team. Bring cultural awareness into a key business discussion." }
      ]
    },
    {
      "id": 46,
      "title": "Public speaking",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Speak for 1 minute on any topic in class", "prompt": "Your teacher gives you one minute to speak on anything you like. Fill it confidently." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Give a 5-minute speech at a college event", "prompt": "You've been asked to address the student body on a topic relevant to campus life." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Deliver a keynote at a professional conference", "prompt": "You're the keynote speaker at an industry conference with 200 attendees. Deliver with authority and engagement." }
      ]
    },
    {
      "id": 47,
      "title": "Handling silence",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Recover from a pause in casual conversation", "prompt": "The conversation dies out for a moment. Restart it naturally without it being awkward." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Use silence strategically in a negotiation", "prompt": "During a negotiation, resist filling every silence. Let pauses work in your favour." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Hold composure during a silent interview moment", "prompt": "The interviewer goes silent after your answer and stares at you. Hold your ground and respond wisely." }
      ]
    },
    {
      "id": 48,
      "title": "Talking about failure",
      "category": "Communication",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Share a time you failed at something with a friend", "prompt": "Tell a friend about a time things didn't go to plan. Be honest and show what you learned." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Discuss a failure in an interview", "prompt": "The interviewer asks: 'Tell me about a time you failed.' Give a composed, reflective answer." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Address a team failure to your organisation", "prompt": "A project your team led didn't succeed. Address the organisation honestly and with a recovery plan." }
      ]
    },
    {
      "id": 49,
      "title": "Wrapping up conversations",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "End a chat with a classmate politely", "prompt": "You need to head to your next class. Close the conversation naturally without being abrupt." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Close a client call professionally", "prompt": "The call has covered everything. Wrap it up clearly with agreed next steps." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Close a multi-hour negotiation meeting", "prompt": "After a long, intense session, bring the meeting to a clear, positive conclusion with all parties aligned." }
      ]
    },
    {
      "id": 50,
      "title": "Building rapport",
      "category": "Social",
      "stages": [
        { "stage": 1, "difficulty": "Easy", "scenario": "Build a quick connection with a new classmate", "prompt": "You have 5 minutes before class. Build genuine rapport with someone you've never spoken to." },
        { "stage": 2, "difficulty": "Medium", "scenario": "Build rapport with a new client", "prompt": "It's your first meeting with a client. Spend the first few minutes creating a warm, trusting connection." },
        { "stage": 3, "difficulty": "Hard", "scenario": "Rebuild rapport after a damaged relationship", "prompt": "A professional relationship went cold after a conflict. Strategically re-establish trust and connection." }
      ]
    }
  ]
}
''';

  static List<CommuniqLevel> get allLevels {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<dynamic> levelsList = data['levels'];
    return levelsList.map((l) => CommuniqLevel.fromJson(l)).toList();
  }
}
