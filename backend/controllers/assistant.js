const Product = require('../models/product');
const mongoose = require('mongoose');
require('dotenv').config();

const GEMINI_API_KEY = process.env.GEMINI_API;
const GROQ_API_KEY = process.env.GROQ_API;

const SECRET_KEY = process.env.SECRET_KEY || 'your-secret-key-change-this';

const GEMINI_FILTER_INSTRUCTION = `You convert natural-language product search requests into a MongoDB query filter JSON for a Product collection.

Product schema:
- title: String
- price: Number
- imageUrl: String

Rules:
- Only use fields "title" and "price". Never output any other field name.
- Allowed operators ONLY: $regex, $options, $gte, $lte, $gt, $lt, $eq, $in, $and, $or.
- "title" may only use $regex (case-insensitive) and/or $in (array of strings). Never put $gte/$lte/etc. on "title".
- "price" may only use $gte, $lte, $gt, $lt, $eq, $in (array of numbers). Never put $regex on "price".
- Do not nest $and/$or more than one level deep.
- For text search use case-insensitive regex on title with $options: "i".
- Return ONLY a raw JSON object (no markdown, no explanation, no comments).

Examples:
- "books under 200" -> {"title":{"$regex":"book","$options":"i"},"price":{"$lte":200}}
- "cheap pens" -> {"title":{"$regex":"pen","$options":"i"},"price":{"$lte":50}}
- "items above 500" -> {"price":{"$gte":500}};`

function parseJsonFromModelText(text) {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const raw = fenced ? fenced[1].trim() : trimmed;
  return JSON.parse(raw);
}

function sanitizeMongoFilter(filter) {
  if (!filter || typeof filter !== 'object' || Array.isArray(filter)) {
    throw new Error('Filter must be a JSON object');
  }

  const serialized = JSON.stringify(filter);
  const blocked = ['$where', '$function', '$accumulator', '$expr', '$jsonSchema'];
  if (blocked.some((op) => serialized.includes(op))) {
    throw new Error('Unsafe filter operators');
  }

  return filter;
}

async function getFilterFromGroq(userPrompt) {
  const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${GROQ_API_KEY}`,
    },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile", // or any Groq model you prefer
      temperature: 0.1,
      messages: [
        {
          role: "system",
          content: GEMINI_FILTER_INSTRUCTION,
        },
        {
          role: "user",
          content: userPrompt,
        },
      ],
    }),
  });

  const payload = await response.json();

  if (!response.ok) {
    const message =
      payload?.error?.message || `Groq request failed (${response.status})`;
    throw new Error(message);
  }

  const text = payload?.choices?.[0]?.message?.content;

  if (!text) {
    throw new Error("Groq returned an empty response");
  }

  return sanitizeMongoFilter(parseJsonFromModelText(text));
}

function fallbackTitleFilter(userPrompt) {
  const words = userPrompt
    .toLowerCase()
    .split(/\s+/)
    .filter((w) => w.length > 2 && !['under', 'above', 'below', 'with', 'the', 'and'].includes(w));

  if (words.length === 0) {
    return { title: { $regex: userPrompt, $options: 'i' } };
  }

  return {
    $or: words.map((word) => ({
      title: { $regex: word, $options: 'i' },
    })),
  };
}


const searchFilter = async (req, res, next) => {
  try {
    const prompt =
      typeof req.body?.prompt === 'string'
        ? req.body.prompt
        : typeof req.body?.message === 'string'
          ? req.body.message
          : '';

    if (!prompt.trim()) {
      return res.status(400).json({ message: 'prompt (non-empty string) required' });
    }

    if (typeof prompt !== 'string' || prompt.length > 256) {
      return res.status(400).json({ message: 'prompt must be 256 characters or fewer' });
    }

    const unsafePatterns = ['<%', '%>', '{{', '}}', '${', '`'];
    if (unsafePatterns.some((pattern) => prompt.includes(pattern))) {
      return res.status(400).json({ message: 'prompt contains unsupported characters or template syntax' });
    }

    if (!GEMINI_API_KEY) {
      console.error('GEMINI_API_KEY is not set in environment variables');
      return res.status(500).json({ message: 'server error' });
    }

    if (!GROQ_API_KEY) {
      console.error('GROQ_API_KEY is not set in environment variables');
      return res.status(500).json({ message: 'Assistant service is unavailable right now.' });
    }

    const trimmedPrompt = prompt.trim();
    let filter;

    try {
      filter = await getFilterFromGroq(trimmedPrompt);
    } catch (groqError) {
      console.warn('Groq filter fallback:', groqError.message);
      filter = fallbackTitleFilter(trimmedPrompt);
    }

    const products = await Product.find(filter).lean();

    res.status(200).json({
      prompt: trimmedPrompt,
      filter,
      products,
      count: products.length,
    });
  } catch (error) {
    console.error('searchFilter error:', error);
    res.status(500).json({
      message: 'Search failed',
      error: error.message,
    });
  }
};

module.exports = {
  searchFilter,
}