<svelte:head>
  <title>GRACE — GRoup of Agents for Creating Entertainment</title>
  <meta
    name="description"
    content="GRACE is a multi-agent film studio that runs entirely on your Mac. Pi directs a crew of local AI agents that write, shoot, voice, score, and deliver a finished short film — with you approving every gate."
  />
  <meta property="og:title" content="GRACE — GRoup of Agents for Creating Entertainment" />
  <meta
    property="og:description"
    content="An idea walks in. A film walks out. A multi-agent film studio that runs entirely on your Mac, built in 24 hours."
  />
  <meta property="og:image" content="https://grace.mere.run/assets/studio.jpg" />
  <meta property="og:url" content="https://grace.mere.run" />
  <meta name="twitter:card" content="summary_large_image" />
</svelte:head>

<nav>
  <div class="wrap nav-inner">
    <a class="brand" href="#top">
      <svg viewBox="0 0 32 32" aria-hidden="true"
        ><circle cx="16" cy="16" r="13" fill="none" stroke="#EDAB4D" stroke-width="2.5" /><g
          stroke="#EDAB4D"
          stroke-width="2"
          stroke-linecap="round"
          ><path d="M16 3.5 L16 16" /><path d="M26.8 9.75 L16 16" /><path
            d="M26.8 22.25 L16 16"
          /><path d="M16 28.5 L16 16" /><path d="M5.2 22.25 L16 16" /><path
            d="M5.2 9.75 L16 16"
          /></g
        ></svg
      >
      GRACE
    </a>
    <div class="nav-links">
      <a href="#how">How it works</a>
      <a href="#crew">The crew</a>
      <a href="#screens">Screens</a>
      <a href="#quickstart">Quickstart</a>
      <a href="https://github.com/sawfwair/mere-film-studio">GitHub</a>
    </div>
  </div>
</nav>

<header id="top">
  <div class="wrap">
    <div class="badge"><span class="dot"></span>BUILT IN 24 HOURS · NOW OPEN TO EVERYONE</div>
    <h1>An idea walks in.<br /><span class="out">A film walks out.</span></h1>
    <p class="sub">
      <strong>GRACE</strong> is a multi-agent film studio that runs entirely on your Mac. Pi directs
      a crew of local AI agents that write, shoot, voice, score, and deliver a finished short film —
      and <strong>nothing advances without your approval</strong>.
    </p>
    <p class="acronym"><b>GR</b>oup of <b>A</b>gents for <b>C</b>reating <b>E</b>ntertainment</p>
    <div class="cta">
      <a class="btn btn-primary" href="#quickstart">Get GRACE</a>
      <a class="btn btn-ghost" href="https://github.com/sawfwair/mere-film-studio">View on GitHub</a>
    </div>
  </div>
  <div class="wrap hero-shot">
    <figure class="shot">
      <img
        src="/assets/studio.jpg"
        alt="The GRACE studio overview: proof dial, department board, and the next human gate"
        loading="eager"
      />
    </figure>
  </div>
  <div class="stats">
    <div class="stat"><b>24 h</b><span>from zero to studio</span></div>
    <div class="stat"><b>6</b><span>agent departments</span></div>
    <div class="stat"><b>5</b><span>human gates</span></div>
    <div class="stat"><b>10</b><span>proofs before delivery</span></div>
    <div class="stat"><b>100%</b><span>local generation</span></div>
  </div>
</header>

<section id="how">
  <div class="wrap">
    <div class="kicker">How it works</div>
    <h2>Five human gates. One durable film.</h2>
    <p class="lede">
      You give GRACE one sentence. The crew develops, blocks, shoots, and mixes — but the production
      halts at every gate until you approve it. Approvals are recorded against content hashes in a
      durable ledger, so a finished film is provable, not just plausible.
    </p>
    <div class="gates">
      <div class="gate">
        <div class="num">01</div>
        <h3>Brief</h3>
        <p>Pi resolves only the material creative questions, then locks the target.</p>
      </div>
      <div class="gate">
        <div class="num">02</div>
        <h3>Treatment</h3>
        <p>Logline, synopsis, beats, and the film's visual and sound language.</p>
      </div>
      <div class="gate">
        <div class="num">03</div>
        <h3>Production</h3>
        <p>Cast and location canon, a shot-by-shot plan, takes, and render budget.</p>
      </div>
      <div class="gate">
        <div class="num">04</div>
        <h3>Picture lock</h3>
        <p>
          Machines provide evidence — QC, vision inspection, independent critics. You lock the
          picture.
        </p>
      </div>
      <div class="gate">
        <div class="num">05</div>
        <h3>Delivery</h3>
        <p>A checksum-backed master, captions, poster — or a verified handoff to Animatic.</p>
      </div>
    </div>
  </div>
</section>

<section id="crew">
  <div class="wrap">
    <div class="kicker">The crew</div>
    <h2>A full creative department, on one laptop.</h2>
    <p class="lede">
      Each department is an agent with a job, a status, and a paper trail. Pi is the
      producer-director; you are the studio head.
    </p>
    <div class="crew">
      <div class="member">
        <h3>Story writer</h3>
        <div class="role">DEVELOPMENT</div>
        <p>Turns the brief into a treatment, beats, and a screenplay worth shooting.</p>
      </div>
      <div class="member">
        <h3>Cinematographer</h3>
        <div class="role">PREPRODUCTION</div>
        <p>Blocks the film shot by shot — purpose, framing, motion, transitions.</p>
      </div>
      <div class="member">
        <h3>Casting director</h3>
        <div class="role">PREPRODUCTION</div>
        <p>Creates canonical cast and location masters so every frame stays consistent.</p>
      </div>
      <div class="member">
        <h3>Sound designer</h3>
        <div class="role">PRODUCTION</div>
        <p>Dialogue performances, authored effects, and score on one accepted timeline.</p>
      </div>
      <div class="member">
        <h3>Continuity supervisor</h3>
        <div class="role">PRODUCTION</div>
        <p>Checks every generated take against the canon before it can be selected.</p>
      </div>
      <div class="member">
        <h3>Independent critic</h3>
        <div class="role">REVIEW</div>
        <p>Reviews the cut with fresh eyes and files targeted reroll requests.</p>
      </div>
    </div>
  </div>
</section>

<section id="screens">
  <div class="wrap">
    <div class="kicker">Screens</div>
    <h2>A native macOS control room.</h2>
    <p class="lede">
      Swift and SwiftUI, with an embedded Ghostty terminal for talking to Pi mid-production. Not a
      web view in a trench coat.
    </p>
    <div class="screens">
      <figure class="screen">
        <div class="shot">
          <img
            src="/assets/shots.jpg"
            alt="Shot board with keyframes, slate strips, and the shot inspector"
            loading="lazy"
          />
        </div>
        <figcaption>
          <b>Shot board.</b> Keyframes, takes, and transitions — hover a shot to preview its clip, right-click
          to reroll.
        </figcaption>
      </figure>
      <figure class="screen">
        <div class="shot">
          <img
            src="/assets/development.jpg"
            alt="Development view with treatment, story beats, and continuity canon"
            loading="lazy"
          />
        </div>
        <figcaption>
          <b>Development.</b> Treatment, story beats, and the continuity canon the whole crew works from.
        </figcaption>
      </figure>
      <figure class="screen">
        <div class="shot">
          <img
            src="/assets/review.jpg"
            alt="Review screen with the proof checklist and studio review action"
            loading="lazy"
          />
        </div>
        <figcaption>
          <b>Review.</b> Machines provide evidence; you lock the picture against its hash.
        </figcaption>
      </figure>
      <figure class="screen">
        <div class="shot">
          <img
            src="/assets/delivery.jpg"
            alt="Delivery screen with proof stack and Animatic handoff"
            loading="lazy"
          />
        </div>
        <figcaption>
          <b>Delivery.</b> Ten proofs, a checksum-bound master, and a verified push to Animatic.
        </figcaption>
      </figure>
    </div>
  </div>
</section>

<section id="proof">
  <div class="wrap">
    <div class="kicker">The proof stack</div>
    <h2>Every promise is proved.</h2>
    <p class="lede">
      Delivery is blocked until all ten checks pass. Change any surface after approval and the lock
      breaks.
    </p>
    <div class="proofs">
      <div class="proof"><span class="tick">✓</span>Creation canon<span>cast + locations</span></div>
      <div class="proof"><span class="tick">✓</span>Selected clips<span>every shot</span></div>
      <div class="proof"><span class="tick">✓</span>Playable assembly<span>real mp4</span></div>
      <div class="proof">
        <span class="tick">✓</span>Dialogue intelligibility<span>ASR-checked</span>
      </div>
      <div class="proof"><span class="tick">✓</span>Sound and loudness<span>-16 LUFS</span></div>
      <div class="proof"><span class="tick">✓</span>Caption sidecars<span>generated</span></div>
      <div class="proof">
        <span class="tick">✓</span>Visual inspection<span>local vision model</span>
      </div>
      <div class="proof">
        <span class="tick">✓</span>Independent review<span>critic agents</span>
      </div>
      <div class="proof"><span class="tick">✓</span>Human decision<span>hash-bound</span></div>
      <div class="proof"><span class="tick">✓</span>Delivery manifest<span>SHA-256</span></div>
    </div>
  </div>
</section>

<section id="models">
  <div class="wrap">
    <div class="kicker">Local by design</div>
    <h2>Every frame made on your machine.</h2>
    <p class="lede">
      GRACE generates through <a href="https://mere.run">mere.run</a>-managed local models on Apple
      Silicon. No cloud render queue, no per-frame bill, and your footage never leaves the laptop.
    </p>
    <div class="models">
      <table>
        <tbody>
          <tr><td>Canon &amp; keyframes</td><td>image models (e.g. flux)</td></tr>
          <tr><td>Shot video</td><td>video models (e.g. wan 2.2)</td></tr>
          <tr><td>Visual inspection</td><td>vision models (e.g. qwen3-vl)</td></tr>
          <tr><td>Voices &amp; dialogue check</td><td>tts + asr (e.g. kokoro, whisper)</td></tr>
          <tr><td>Score &amp; effects</td><td>music + sfx (e.g. musicgen)</td></tr>
          <tr><td>Direction &amp; crew</td><td>Pi on a local agent model</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</section>

<section id="quickstart">
  <div class="wrap">
    <div class="kicker">Quickstart</div>
    <h2>Try it yourself.</h2>
    <p class="lede">
      GRACE is open source. You bring an Apple Silicon Mac and the local toolchain; it brings the
      studio.
    </p>
    <pre><span class="c"># Requires Apple Silicon macOS 15+, Xcode 26+, XcodeGen</span>
<span class="p">$</span> git clone https://github.com/sawfwair/mere-film-studio
<span class="p">$</span> cd mere-film-studio
<span class="p">$</span> brew install xcodegen
<span class="p">$</span> ./scripts/check.sh        <span class="c"># lint, tests, and a full app build</span>
<span class="p">$</span> open MereFilmStudio.xcodeproj

<span class="c"># Optional: package a drag-to-Applications disk image</span>
<span class="p">$</span> ./scripts/package-app.sh</pre>
    <p class="req">
      Runtime requirements: <code>mere-film-tools</code>, <code>pi</code>, a
      <code>mere.run</code> build with inline agent support, <code>ffmpeg</code>/<code>ffprobe</code
      >, and <code>animatic</code> only if you publish a handoff. The app discovers MereRun-managed
      Pi installs automatically and never reads or stores provider secrets.
    </p>
  </div>
</section>

<footer>
  <div class="wrap foot">
    <span class="brand">GRACE</span>
    <span>GRoup of Agents for Creating Entertainment</span>
    <span class="spacer"></span>
    <span
      >Built in 24 hours on <a href="https://mere.run">mere.run</a> ·
      <a href="https://github.com/sawfwair/mere-film-studio">Source on GitHub</a></span
    >
  </div>
</footer>
