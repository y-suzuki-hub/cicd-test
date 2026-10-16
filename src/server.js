import { createApp } from './app.js';

const port = Number(process.env.PORT ?? 3000);
const app = createApp({ version: process.env.APP_VERSION ?? 'dev' });

app.listen(port, () => console.log(`listening on :${port}`));

// ECS stops tasks with SIGTERM; close cleanly so in-flight requests finish during rollouts.
process.on('SIGTERM', () => app.close(() => process.exit(0)));
