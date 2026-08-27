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

// async function generateReviewSummary(existingSummary, reviews) {
//     const apiKey = GPT_API_KEY;
//     if (!apiKey) {
//         throw new Error('No LLM API key configured (GPT_API)');
//     }

//     const prompt = `You are a product review summarization assistant.\nExisting summary:\n${existingSummary || 'No previous summary available.'}\n\nNew reviews:\n${reviews}\n\nUsing the existing summary and these new reviews, write a concise updated summary of the product. Return only the summary text.`;

//     // Prefer OpenAI-style GPT API when GPT_API_KEY is available
//         const url = 'https://api.openai.com/v1/chat/completions';
//         const response = await fetch(url, {
//             method: 'POST',
//             headers: {
//                 'Content-Type': 'application/json',
//                 'Authorization': `Bearer ${GPT_API_KEY}`,
//             },
//             body: JSON.stringify({
//                 model: 'gpt-3.5-turbo',
//                 messages: [
//                     { role: 'system', content: 'You summarize product reviews.' },
//                     { role: 'user', content: prompt },
//                 ],
//                 max_tokens: 400,
//                 temperature: 0.2,
//             }),
//         });

//         const payload = await response.json();
//         if (!response.ok) {
//             const message = payload?.error?.message || `GPT request failed (${response.status})`;
//             throw new Error(message);
//         }

//         console.log(payload?.choices?.[0]?.message?.content?.trim());

//         return payload?.choices?.[0]?.message?.content?.trim() || '';


//     // Fallback to Gemini if GPT_API_KEY not present
//     // const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;
//     // const response = await fetch(url, {
//     //     method: 'POST',
//     //     headers: { 'Content-Type': 'application/json' },
//     //     body: JSON.stringify({
//     //         contents: [
//     //             {
//     //                 role: 'user',
//     //                 parts: [{ text: prompt }],
//     //             },
//     //         ],
//     //         generationConfig: {
//     //             temperature: 0.2,
//     //             responseMimeType: 'text/plain',
//     //         },
//     //     }),
//     // });

//     // const payload = await response.json();
//     // if (!response.ok) {
//     //     const message = payload?.error?.message || `Gemini request failed (${response.status})`;
//     //     throw new Error(message);
//     // }

//     // return payload?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
//  }

// async function ensureSummaryFromExistingReviews(prodId) {
//     if (!prodId) {
//         return null;
//     }

//     const reviews = await Rating.find({ productId: prodId }).sort({ createdAt: 1 });
//     console.log("reviews length : ",reviews.length);

//     let summaryDoc = await Summary.findOne({ prodId });
//     console.log("summaryDoc : ",summaryDoc);

//     if (!reviews || reviews.length < 10) {
//         if (summaryDoc && Array.isArray(summaryDoc.buffer) && summaryDoc.buffer.length >= 10) {
//             try {
//                 const generated = await generateReviewSummary(summaryDoc.summary || '', summaryDoc.buffer.join('\n'));
//                 if (generated) {
//                     summaryDoc.summary = generated;
//                     summaryDoc.buffer = [];
//                     await summaryDoc.save();
//                 }
//             } catch (error) {
//                 console.error('ensureSummaryFromExistingReviews buffer generation failed:', error.message || error);
//             }
//         }
//         return summaryDoc;
//     }

//     if (!summaryDoc) {
//         summaryDoc = new Summary({ prodId, summary: '', buffer: [] });
//     }

//     const lastReviews = reviews
//         .slice(-10)
//         .map((r) => r.description || '')
//         .filter((text) => text.trim().length > 0);

//     if (lastReviews.length > 0) {
//         if (!summaryDoc.summary || summaryDoc.summary.trim() === '') {
//             try {
//                 summaryDoc.summary = await generateReviewSummary('', lastReviews.join('\n'));
//                 summaryDoc.buffer = [];
//             } catch (error) {
//                 console.error('ensureSummaryFromExistingReviews failed:', error.message || error);
//             }
//         } else {
//             const existingSummary = summaryDoc.summary;
//             try {
//                 summaryDoc.summary = await generateReviewSummary(existingSummary, lastReviews.join('\n'));
//             } catch (error) {
//                 console.error('ensureSummaryFromExistingReviews failed:', error.message || error);
//             }
//         }
//     }

//     await summaryDoc.save();
//     return summaryDoc;
// }

// const getSummary = async (newReview, prodId) => {
//     if (!prodId || !newReview) {
//         return;
//     }

//     let summaryDoc = await Summary.findOne({ prodId });
//     if (!summaryDoc) {
//         summaryDoc = new Summary({ prodId, summary: '', buffer: [] });
//     }

//     summaryDoc.buffer = Array.isArray(summaryDoc.buffer) ? summaryDoc.buffer : [];
//     summaryDoc.buffer.push(newReview);

//     if (summaryDoc.buffer.length >= 10) {
//         try {
//             const joinedReviews = summaryDoc.buffer.join('\n');
//             const generated = await generateReviewSummary(summaryDoc.summary, joinedReviews);
//             if (generated) {
//                 summaryDoc.summary = generated;
//                 summaryDoc.buffer = [];
//             }

//         } catch (error) {
//             console.error('Failed to generate summary:', error.message || error);
//         }
//     }

//     await summaryDoc.save();
// };

// const fetchSummary = async (req, res) => {
//     try {
//         const { prodId } = req.params;

//         if (!prodId) {
//             return res.status(400).json({
//                 success: false,
//                 message: 'Product ID is required'
//             });
//         }

//         let summaryDoc = await Summary.findOne({ prodId });

//         console.log("summaryDoc before:", summaryDoc);

//         if (summaryDoc && (!summaryDoc.summary || summaryDoc.summary.trim() === '') && Array.isArray(summaryDoc.buffer) && summaryDoc.buffer.length >= 10) {
//             try {
//                 const generated = await generateReviewSummary(summaryDoc.summary, summaryDoc.buffer.join('\n'));
//                 if (generated) {
//                     summaryDoc.summary = generated;
//                     summaryDoc.buffer = [];
//                     await summaryDoc.save();
//                 }
//             } catch (error) {
//                 console.error('fetchSummary buffer generation failed:', error.message || error);
//             }
//         }

//         if (!summaryDoc || !summaryDoc.summary) {
//             summaryDoc = await ensureSummaryFromExistingReviews(prodId);
//         }

//         console.log("summaryDoc after:", summaryDoc);

//         if (!summaryDoc || !summaryDoc.summary) {
//             return res.status(200).json({
//                 success: true,
//                 summary: 'Not available'
//             });
//         }

//         return res.status(200).json({
//             success: true,
//             summary: summaryDoc.summary
//         });

//     } catch (error) {
//         console.error('fetchSummary errrrrrrror:', error);

//         return res.status(500).json({
//             success: false,
//             message: 'Failed to fetch summary'
//         });
//     }
// };

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
        const productId = req.params.productId;
        if (!productId) {
            return res.status(400).json({
                message: 'Product ID is required'
            });
        }

        const n8nUrl = `http://localhost:5678/webhook-test/ae69089e-6050-41c0-a4da-47ab2822481c/fetchSummary/${productId}`;

        let response;
        try {
            response = await fetch(n8nUrl, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                }
            });
        } catch (err) {
            console.error('fetchSummaryFromN8N request failed:', err);
            return res.status(502).json({ message: 'Failed to contact N8N', error: err.message });
        }
        console.log("fetchSummaryFromN8N response status:", response.status);
        const data = await response.json();
        console.log('fetchSummaryFromN8N response data:', data);

        if (!response.ok) {
            console.error('fetchSummaryFromN8N bad status:', response.status, data);
            return res.status(502).json({
                message: 'N8N returned an error',
                status: response.status,
                errorData: data,
            });
        }

        let summaryText;
        if (Array.isArray(data) && data.length > 0 && typeof data[0]?.output === 'string') {
            summaryText = data[0].output;
        } else if (data && typeof data.output === 'string') {
            summaryText = data.output;
        }

        if (!summaryText) {
            console.error('fetchSummaryFromN8N unexpected payload shape:', data);
            return res.status(502).json({
                message: 'Unexpected N8N response format',
                responseData: data,
            });
        }

        return res.status(200).json({
            message: 'Summary fetched successfully',
            summary: summaryText,
        });

    } catch (error) {
        console.error('fetchSummaryFromN8N error:', error);
        return res.status(500).json({
            message: 'Failed to fetch summary from N8N',
            error: error.message || error,
        });
    }
};

module.exports = {
    fetchRatings,
    // fetchSummary,
    addRating,
    upvote,
    downvote,
    fetchSummaryFromN8N
};

