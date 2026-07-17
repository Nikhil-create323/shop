const Product = require('../models/product');
const Rating = require('../models/rating');
const Summary = require('../models/summary');

// const GEMINI_API_KEY = process.env.GEMINI_API;
const GPT_API_KEY = process.env.GPT_API;
const GROQ_API_KEY = process.env.GROQ_API;

const mapRatingToFrontend = (rating) => {
    return {
        id: rating._id,
        _id: rating._id,
        rating: rating.rating,
        productId: rating.productId,
        user: rating.user ? rating.user.toString() : '',
        description: rating.description || '',
        likeCount: rating.likedBy ? rating.likedBy.length : 0,
        dislikeCount: rating.dislikedBy ? rating.dislikedBy.length : 0,
        likedBy: rating.likedBy || [],
        dislikedBy: rating.dislikedBy || [],
        timestamp: rating.createdAt || new Date(),
    };
};

async function generateReviewSummary(existingSummary, reviews) {
    const apiKey = GPT_API_KEY;
    if (!apiKey) {
        throw new Error('No LLM API key configured (GPT_API)');
    }

    const prompt = `You are a product review summarization assistant.\nExisting summary:\n${existingSummary || 'No previous summary available.'}\n\nNew reviews:\n${reviews}\n\nUsing the existing summary and these new reviews, write a concise updated summary of the product. Return only the summary text.`;

    // Prefer OpenAI-style GPT API when GPT_API_KEY is available
        const url = 'https://api.openai.com/v1/chat/completions';
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${GPT_API_KEY}`,
            },
            body: JSON.stringify({
                model: 'gpt-3.5-turbo',
                messages: [
                    { role: 'system', content: 'You summarize product reviews.' },
                    { role: 'user', content: prompt },
                ],
                max_tokens: 400,
                temperature: 0.2,
            }),
        });

        const payload = await response.json();
        if (!response.ok) {
            const message = payload?.error?.message || `GPT request failed (${response.status})`;
            throw new Error(message);
        }

        console.log(payload?.choices?.[0]?.message?.content?.trim());

        return payload?.choices?.[0]?.message?.content?.trim() || '';


    // Fallback to Gemini if GPT_API_KEY not present
    // const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;
    // const response = await fetch(url, {
    //     method: 'POST',
    //     headers: { 'Content-Type': 'application/json' },
    //     body: JSON.stringify({
    //         contents: [
    //             {
    //                 role: 'user',
    //                 parts: [{ text: prompt }],
    //             },
    //         ],
    //         generationConfig: {
    //             temperature: 0.2,
    //             responseMimeType: 'text/plain',
    //         },
    //     }),
    // });

    // const payload = await response.json();
    // if (!response.ok) {
    //     const message = payload?.error?.message || `Gemini request failed (${response.status})`;
    //     throw new Error(message);
    // }

    // return payload?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
 }

async function ensureSummaryFromExistingReviews(prodId) {
    if (!prodId) {
        return null;
    }

    const reviews = await Rating.find({ productId: prodId }).sort({ createdAt: 1 });
    console.log("reviews length : ",reviews.length);

    let summaryDoc = await Summary.findOne({ prodId });
    console.log("summaryDoc : ",summaryDoc);

    if (!reviews || reviews.length < 10) {
        if (summaryDoc && Array.isArray(summaryDoc.buffer) && summaryDoc.buffer.length >= 10) {
            try {
                const generated = await generateReviewSummary(summaryDoc.summary || '', summaryDoc.buffer.join('\n'));
                if (generated) {
                    summaryDoc.summary = generated;
                    summaryDoc.buffer = [];
                    await summaryDoc.save();
                }
            } catch (error) {
                console.error('ensureSummaryFromExistingReviews buffer generation failed:', error.message || error);
            }
        }
        return summaryDoc;
    }

    if (!summaryDoc) {
        summaryDoc = new Summary({ prodId, summary: '', buffer: [] });
    }

    const lastReviews = reviews
        .slice(-10)
        .map((r) => r.description || '')
        .filter((text) => text.trim().length > 0);

    if (lastReviews.length > 0) {
        if (!summaryDoc.summary || summaryDoc.summary.trim() === '') {
            try {
                summaryDoc.summary = await generateReviewSummary('', lastReviews.join('\n'));
                summaryDoc.buffer = [];
            } catch (error) {
                console.error('ensureSummaryFromExistingReviews failed:', error.message || error);
            }
        } else {
            const existingSummary = summaryDoc.summary;
            try {
                summaryDoc.summary = await generateReviewSummary(existingSummary, lastReviews.join('\n'));
            } catch (error) {
                console.error('ensureSummaryFromExistingReviews failed:', error.message || error);
            }
        }
    }

    await summaryDoc.save();
    return summaryDoc;
}

const getSummary = async (newReview, prodId) => {
    if (!prodId || !newReview) {
        return;
    }

    let summaryDoc = await Summary.findOne({ prodId });
    if (!summaryDoc) {
        summaryDoc = new Summary({ prodId, summary: '', buffer: [] });
    }

    summaryDoc.buffer = Array.isArray(summaryDoc.buffer) ? summaryDoc.buffer : [];
    summaryDoc.buffer.push(newReview);

    if (summaryDoc.buffer.length >= 10) {
        try {
            const joinedReviews = summaryDoc.buffer.join('\n');
            const generated = await generateReviewSummary(summaryDoc.summary, joinedReviews);
            if (generated) {
                summaryDoc.summary = generated;
                summaryDoc.buffer = [];
            }

        } catch (error) {
            console.error('Failed to generate summary:', error.message || error);
        }
    }

    await summaryDoc.save();
};

const fetchSummary = async (req, res) => {
    try {
        const { prodId } = req.params;

        if (!prodId) {
            return res.status(400).json({
                success: false,
                message: 'Product ID is required'
            });
        }

        let summaryDoc = await Summary.findOne({ prodId });

        console.log("summaryDoc before:", summaryDoc);

        if (summaryDoc && (!summaryDoc.summary || summaryDoc.summary.trim() === '') && Array.isArray(summaryDoc.buffer) && summaryDoc.buffer.length >= 10) {
            try {
                const generated = await generateReviewSummary(summaryDoc.summary, summaryDoc.buffer.join('\n'));
                if (generated) {
                    summaryDoc.summary = generated;
                    summaryDoc.buffer = [];
                    await summaryDoc.save();
                }
            } catch (error) {
                console.error('fetchSummary buffer generation failed:', error.message || error);
            }
        }

        if (!summaryDoc || !summaryDoc.summary) {
            summaryDoc = await ensureSummaryFromExistingReviews(prodId);
        }

        console.log("summaryDoc after:", summaryDoc);

        if (!summaryDoc || !summaryDoc.summary) {
            return res.status(200).json({
                success: true,
                summary: 'Not available'
            });
        }

        return res.status(200).json({
            success: true,
            summary: summaryDoc.summary
        });

    } catch (error) {
        console.error('fetchSummary error:', error);

        return res.status(500).json({
            success: false,
            message: 'Failed to fetch summary'
        });
    }
};

const fetchRatings = async (req, res) => {
    try {
        const ratings = await Rating.find({
            productId: req.params.productId
        });

        const mappedRatings = ratings.map(r =>
            mapRatingToFrontend(r)
        );

        // const summaryDoc = await Summary.findOne({ prodId: req.params.productId });

        res.status(200).json({
            message: "Ratings fetched successfully",
            ratings: mappedRatings,
            // summary: summaryDoc ? summaryDoc.summary : ''
        });

    } catch (error) {
        res.status(500).json({
            message: error.message
        });
    }
};

const addRating = async (req, res) => {
    try {

        const prodId = req.params.productId;

        const { user, rating, description } = req.body;

        if (!user || rating === undefined || !description) {
            return res.status(400).json({
                message: "User, rating, and description are required"
            });
        }

        const newRating = await Rating.create({
            productId: prodId,
            user,
            rating,
            description,
            likedBy: [],
            dislikedBy: []
        });

        await getSummary(description, prodId);

        const mappedRatings = mapRatingToFrontend(newRating);

        res.status(200).json({
            message: "Rating added successfully",
            ratings: mappedRatings,
        });

    } catch (error) {

        console.error(error);

        res.status(500).json({
            message: error.message
        });
    }
};

const upvote = async (req, res) => {
    try {

        const { userId } = req.body;

        const rating = await Rating.findById(
            req.params.ratingId
        );

        if (!rating) {
            return res.status(404).json({
                message: "Rating not found"
            });
        }

        const alreadyLiked = rating.likedBy.includes(userId);

        if (alreadyLiked) {

            rating.likedBy = rating.likedBy.filter(
                id => id.toString() !== userId
            );

        } else {

            rating.likedBy.push(userId);

            rating.dislikedBy = rating.dislikedBy.filter(
                id => id.toString() !== userId
            );
        }

        await rating.save();

        const ratings = await Rating.find({ productId: rating.productId });
        const mappedRatings = ratings.map(mapRatingToFrontend);

        res.status(200).json({
            message: "Upvote successful",
            ratings: mappedRatings,
            rating: mapRatingToFrontend(rating)
        });

    } catch (error) {
        res.status(500).json({
            message: error.message
        });
    }
};

const downvote = async (req, res) => {
    try {

        const { userId } = req.body;

        const rating = await Rating.findById(
            req.params.ratingId
        );

        if (!rating) {
            return res.status(404).json({
                message: "Rating not found"
            });
        }

        const alreadyDisliked = rating.dislikedBy.includes(userId);

        if (alreadyDisliked) {

            rating.dislikedBy = rating.dislikedBy.filter(
                id => id.toString() !== userId
            );

        } else {

            rating.dislikedBy.push(userId);

            rating.likedBy = rating.likedBy.filter(
                id => id.toString() !== userId
            );
        }

        await rating.save();

        const ratings = await Rating.find({ productId: rating.productId });
        const mappedRatings = ratings.map(mapRatingToFrontend);

        res.status(200).json({
            message: "Downvote successful",
            ratings: mappedRatings,
            rating: mapRatingToFrontend(rating)
        });

    } catch (error) {
        res.status(500).json({
            message: error.message
        });
    }
};

const fetchSummaryFromN8N = async (req, res) => {
    try {
        const productId = req.params.productId || req.params.prodId;
        if (!productId) {
            return res.status(400).json({
                message: 'Product ID is required'
            });
        }

        // Load summary document and ensure buffer is an array
        let summaryDoc = await Summary.findOne({ prodId: productId });
        if (!summaryDoc) {
            return res.status(200).json({ summary: 'Not available' });
        }

        summaryDoc.buffer = Array.isArray(summaryDoc.buffer) ? summaryDoc.buffer : [];

        // Only call N8N when we have enough buffered reviews
        if (summaryDoc.buffer.length < 10) {
            return res.status(200).json({ summary: summaryDoc.summary || 'Not available' });
        }

        const n8nUrl = `http://localhost:5678/webhook-test/ae69089e-6050-41c0-a4da-47ab2822481c/fetchSummary/${productId}`;

        // Prefer POST with the buffered reviews, but fall back to GET if the webhook rejects POST.
        let response;
        try {
            response = await fetch(n8nUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ prodId: productId, buffer: summaryDoc.buffer }),
            });
        } catch (err) {
            console.error('fetchSummaryFromN8N request failed:', err);
            return res.status(502).json({ message: 'Failed to contact N8N' });
        }

        if (!response.ok) {
            // Attempt a safe fallback to GET (some workflows expect GET)
            try {
                const fallback = await fetch(n8nUrl);
                if (!fallback.ok) {
                    return res.status(fallback.status).json({ message: 'N8N workflow returned an error' });
                }
                response = fallback;
            } catch (err) {
                return res.status(response.status).json({ message: 'N8N workflow returned an error' });
            }
        }

        const data = await response.json();

        // n8n might return an array or an object; handle common shapes
        let summaryText = '';
        if (Array.isArray(data)) {
            summaryText = data[0]?.output || data[0]?.summary || '';
        } else if (data && typeof data === 'object') {
            summaryText = data.output || data.summary || data.result || '';
        } else if (typeof data === 'string') {
            summaryText = data;
        }

        if (summaryText && summaryText.trim() !== '') {
            // update DB and clear buffer only when n8n produced a non-empty summary
            summaryDoc.summary = summaryText.trim();
            summaryDoc.buffer = [];
            await summaryDoc.save();

            return res.status(200).json({ summary: summaryDoc.summary });
        }

        return res.status(200).json({ summary: 'Not available' });

    } catch (error) {
        console.error('fetchSummaryFromN8N error:', error);
        return res.status(500).json({
            message: 'Failed to fetch summary from N8N'
        });
    }
};

module.exports = {
    fetchRatings,
    fetchSummary,
    addRating,
    upvote,
    downvote,
    fetchSummaryFromN8N
};

