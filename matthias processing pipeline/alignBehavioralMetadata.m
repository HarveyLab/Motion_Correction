function movMetadata = alignBehavioralMetadata(movMetadata, syncMetadata, sn)

% Aligns synchronization metadata (behavioral and stimulation) to the
% frames in the movie associated with movMetadata. movMetadata must be an
% array of movMetadatas containing all tiff chunks associated with the
% acquisition in syncMetadata.

% General purpose of this function: assign a behavior frame number to each
% 2p frame, and vice versa. Then, if we, for example, want to align all mem
% trials to the pointer-on time, 

chPprojectorFlipClock = 3;
chTaskMetadata = 4;
chScanimageFrameClock = 5;
